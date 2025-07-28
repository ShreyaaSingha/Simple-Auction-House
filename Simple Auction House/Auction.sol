// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SimpleAuctionHouse
 * @dev A decentralized auction house for buying and selling items
 * @author Your Name
 */
contract SimpleAuctionHouse {
    
    struct Auction {
        address seller;
        string itemName;
        string itemDescription;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 auctionEndTime;
        bool ended;
        bool exists;
    }
    
    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => mapping(address => uint256)) public pendingReturns;
    
    uint256 private nextAuctionId = 1;
    uint256 public totalAuctions = 0;
    
    event AuctionCreated(
        uint256 indexed auctionId,
        address indexed seller,
        string itemName,
        uint256 startingPrice,
        uint256 duration
    );
    
    event BidPlaced(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    
    event AuctionEnded(
        uint256 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );
    
    event WithdrawalMade(
        uint256 indexed auctionId,
        address indexed bidder,
        uint256 amount
    );
    
    modifier auctionExists(uint256 _auctionId) {
        require(auctions[_auctionId].exists, "Auction does not exist");
        _;
    }
    
    modifier onlyBeforeEnd(uint256 _auctionId) {
        require(block.timestamp < auctions[_auctionId].auctionEndTime, "Auction has ended");
        _;
    }
    
    modifier onlyAfterEnd(uint256 _auctionId) {
        require(block.timestamp >= auctions[_auctionId].auctionEndTime, "Auction still ongoing");
        _;
    }
    
    /**
     * @dev Creates a new auction
     * @param _itemName Name of the item being auctioned
     * @param _itemDescription Description of the item
     * @param _startingPrice Minimum bid amount in wei
     * @param _durationInMinutes Duration of auction in minutes
     * @return auctionId The ID of the created auction
     */
    function createAuction(
        string memory _itemName,
        string memory _itemDescription,
        uint256 _startingPrice,
        uint256 _durationInMinutes
    ) external returns (uint256) {
        require(_startingPrice > 0, "Starting price must be greater than 0");
        require(_durationInMinutes > 0, "Duration must be greater than 0");
        require(bytes(_itemName).length > 0, "Item name cannot be empty");
        
        uint256 auctionId = nextAuctionId++;
        
        auctions[auctionId] = Auction({
            seller: msg.sender,
            itemName: _itemName,
            itemDescription: _itemDescription,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            auctionEndTime: block.timestamp + (_durationInMinutes * 1 minutes),
            ended: false,
            exists: true
        });
        
        totalAuctions++;
        
        emit AuctionCreated(auctionId, msg.sender, _itemName, _startingPrice, _durationInMinutes);
        
        return auctionId;
    }
    
    /**
     * @dev Places a bid on an auction
     * @param _auctionId ID of the auction to bid on
     */
    function placeBid(uint256 _auctionId) 
        external 
        payable 
        auctionExists(_auctionId) 
        onlyBeforeEnd(_auctionId) 
    {
        Auction storage auction = auctions[_auctionId];
        
        require(msg.sender != auction.seller, "Seller cannot bid on own auction");
        require(msg.value > auction.startingPrice, "Bid must be higher than starting price");
        require(msg.value > auction.highestBid, "Bid must be higher than current highest bid");
        
        // Return the previous highest bid to the previous bidder
        if (auction.highestBidder != address(0)) {
            pendingReturns[_auctionId][auction.highestBidder] += auction.highestBid;
        }
        
        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;
        
        emit BidPlaced(_auctionId, msg.sender, msg.value);
    }
    
    /**
     * @dev Ends an auction and transfers funds
     * @param _auctionId ID of the auction to end
     */
    function endAuction(uint256 _auctionId) 
        external 
        auctionExists(_auctionId) 
        onlyAfterEnd(_auctionId) 
    {
        Auction storage auction = auctions[_auctionId];
        require(!auction.ended, "Auction already ended");
        
        auction.ended = true;
        
        // Transfer winning bid to seller if there was a bidder
        if (auction.highestBidder != address(0)) {
            payable(auction.seller).transfer(auction.highestBid);
            emit AuctionEnded(_auctionId, auction.highestBidder, auction.highestBid);
        } else {
            emit AuctionEnded(_auctionId, address(0), 0);
        }
    }
    
    /**
     * @dev Allows unsuccessful bidders to withdraw their bids
     * @param _auctionId ID of the auction
     */
    function withdrawBid(uint256 _auctionId) external auctionExists(_auctionId) {
        uint256 amount = pendingReturns[_auctionId][msg.sender];
        require(amount > 0, "No funds to withdraw");
        
        pendingReturns[_auctionId][msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        
        emit WithdrawalMade(_auctionId, msg.sender, amount);
    }
    
    /**
     * @dev Gets auction details
     * @param _auctionId ID of the auction
     * @return seller Address of the auction seller
     * @return itemName Name of the auctioned item
     * @return itemDescription Description of the auctioned item
     * @return startingPrice Starting price of the auction
     * @return highestBid Current highest bid amount
     * @return highestBidder Address of the current highest bidder
     * @return auctionEndTime Timestamp when auction ends
     * @return ended Whether the auction has been ended
     * @return isActive Whether the auction is currently active
     */
    function getAuctionDetails(uint256 _auctionId) 
        external 
        view 
        auctionExists(_auctionId) 
        returns (
            address seller,
            string memory itemName,
            string memory itemDescription,
            uint256 startingPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 auctionEndTime,
            bool ended,
            bool isActive
        ) 
    {
        Auction storage auction = auctions[_auctionId];
        return (
            auction.seller,
            auction.itemName,
            auction.itemDescription,
            auction.startingPrice,
            auction.highestBid,
            auction.highestBidder,
            auction.auctionEndTime,
            auction.ended,
            block.timestamp < auction.auctionEndTime && !auction.ended
        );
    }
    
    /**
     * @dev Gets the amount available for withdrawal for a specific bidder
     * @param _auctionId ID of the auction
     * @param _bidder Address of the bidder
     * @return Amount available for withdrawal
     */
    function getPendingReturn(uint256 _auctionId, address _bidder) 
        external 
        view 
        returns (uint256) 
    {
        return pendingReturns[_auctionId][_bidder];
    }
}
