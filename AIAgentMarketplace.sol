// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract AIAgentMarketplace {
    struct Agent {
        address seller;
        uint256 price;
        bool isListed;
        string metadata; // URI pointing to agent details stored off-chain
    }

    address public owner;
    address public platformWallet;
    uint256 public platformFeePercent = 15; // 1.5% = 15/1000
    IERC20 public mktToken;
    
    // agentId => Agent
    mapping(uint256 => Agent) public agents;
    uint256 public nextAgentId;

    event AgentListed(uint256 indexed agentId, address seller, uint256 price, string metadata);
    event AgentPurchased(uint256 indexed agentId, address buyer, uint256 price);
    event AgentDelisted(uint256 indexed agentId, address delistedBy);
    event PriceUpdated(uint256 indexed agentId, uint256 newPrice);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlySellerOrOwner(uint256 agentId) {
        require(
            msg.sender == agents[agentId].seller || msg.sender == owner,
            "Only seller or owner can call this function"
        );
        _;
    }

    constructor(address _mktToken, address _platformWallet) {
        owner = msg.sender;
        mktToken = IERC20(_mktToken);
        platformWallet = _platformWallet;
    }

    function publishAgent(uint256 price, string memory metadata) external returns (uint256) {
        require(price > 0, "Price must be greater than 0");
        
        uint256 agentId = nextAgentId++;
        agents[agentId] = Agent({
            seller: msg.sender,
            price: price,
            isListed: true,
            metadata: metadata
        });

        emit AgentListed(agentId, msg.sender, price, metadata);
        return agentId;
    }

    function buyAgent(uint256 agentId) external {
        Agent storage agent = agents[agentId];
        require(agent.isListed, "Agent not listed or has been delisted");
        require(msg.sender != agent.seller, "Cannot buy your own agent");

        uint256 platformFee = (agent.price * platformFeePercent) / 1000;
        uint256 sellerAmount = agent.price - platformFee;

        require(mktToken.transferFrom(msg.sender, platformWallet, platformFee), "Platform fee transfer failed");
        require(mktToken.transferFrom(msg.sender, agent.seller, sellerAmount), "Seller transfer failed");

        emit AgentPurchased(agentId, msg.sender, agent.price);
    }

    function delistAgent(uint256 agentId) external onlySellerOrOwner(agentId) {
        Agent storage agent = agents[agentId];
        require(agent.isListed, "Agent already delisted");
        
        agent.isListed = false;
        emit AgentDelisted(agentId, msg.sender);
    }

    function updatePrice(uint256 agentId, uint256 newPrice) external {
        Agent storage agent = agents[agentId];
        require(msg.sender == agent.seller, "Only seller can update price");
        require(agent.isListed, "Agent not listed or has been delisted");
        require(newPrice > 0, "Price must be greater than 0");

        agent.price = newPrice;
        emit PriceUpdated(agentId, newPrice);
    }
}