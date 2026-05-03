/**
 *Submitted for verification at BscScan.com on 2026-05-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// interface IERC20 {
//     function transfer(
//         address recipient,
//         uint256 amount
//     ) external returns (bool);
// }

// ================= OWNABLE =================
contract Ownable {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function renounceOwnership() external onlyOwner {
        owner = address(0);
    }
}

// ================= ERC20 FULL =================
contract ERC20 is Ownable {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(string memory _name, string memory _symbol, uint256 _supply) {
        name = _name;
        symbol = _symbol;
        _mint(msg.sender, _supply * 1e18);
    }

    function _mint(address to, uint256 amount) internal {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Low balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 added
    ) external returns (bool) {
        allowance[msg.sender][spender] += added;
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 sub
    ) external returns (bool) {
        allowance[msg.sender][spender] -= sub;
        return true;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(balanceOf[from] >= amount, "Balance low");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        emit Transfer(from, to, amount);
    }
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        require(allowance[from][msg.sender] >= amount, "Allowance low");
        allowance[from][msg.sender] -= amount;
        _transfer(from, to, amount);
        return true;
    }
}
interface IPancakeRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function factory() external pure returns (address);
}

interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);
}
// ================= MAIN TOKEN =================
contract MetaProSpaceToken is ERC20 {
    IPancakeRouter public router;

    function setRouter(address _router) external onlyOwner {
        router = IPancakeRouter(_router);
    }
    struct Tax {
        uint256 dev;
        uint256 marketing;
        uint256 charity;
        uint256 liquidity;
    }
    Tax public buyTax;
    Tax public sellTax;
    address public usdtToken;
    address public devWallet;
    address public marketingWallet;
    address public mpsFoundation;
    address public liquidityWallet;
    address public dividendToken;
    uint256 public minDividendBalance;
    mapping(address => bool) public isFeeExempt;
    uint256 public lastProcess;
    address public backendWallet;
    bool public claimEnabled;
    mapping(address => uint256) public claimedAmount;
    uint256 public minHolding = 1000 * 1e18;
    uint256 public dailyReward = 1 * 1e18;
    uint256 public maxClaimPerTx = 10 * 1e18;

    mapping(address => uint256) public lastClaim;
    constructor() ERC20("MetaProSpaceToken", "MPST", 1000000000) {
        isFeeExempt[msg.sender] = true;
        backendWallet = msg.sender;
    }
    // ================= ADMIN =================
    function setBackendWallet(address _wallet) external onlyOwner {
        backendWallet = _wallet;
    }
    function setUSDT(address _usdt) external onlyOwner {
        usdtToken = _usdt;
    }
    function buyWithUSDT(uint256 amountIn, uint256 minOut) external {
        require(amountIn > 0, "Invalid amount");

        // USER se USDT lo
        IERC20(usdtToken).transferFrom(msg.sender, address(this), amountIn);

        // Router ko approve karo
        IERC20(usdtToken).approve(address(router), amountIn);

        // Path: USDT → MPS
        address[] memory path = new address[](2);
        path[0] = usdtToken;
        path[1] = address(this);

        // REAL SWAP
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            minOut, // slippage control
            path,
            msg.sender, // direct user ko token
            block.timestamp
        );
    }
    function sellForUSDT(uint256 amountIn, uint256 minOut) external {
        require(amountIn > 0, "Invalid amount");
        require(balanceOf[msg.sender] >= amountIn, "Low balance");

        // allowance check
        require(
            allowance[msg.sender][address(this)] >= amountIn,
            "Approve first"
        );

        // allowance reduce
        allowance[msg.sender][address(this)] -= amountIn;

        // ✅ TAX + DIVIDEND APPLY HOGA
        _transfer(msg.sender, address(this), amountIn);

        // approve router
        IERC20(address(this)).approve(address(router), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = usdtToken;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            minOut,
            path,
            msg.sender,
            block.timestamp
        );
    }
    function claimDailyReward() external {
        require(claimEnabled, "Claim disabled");
        require(balanceOf[msg.sender] >= minHolding, "Not eligible");

        uint256 lastTime = lastClaim[msg.sender];

        // First time fix
        if (lastTime == 0) {
            lastClaim[msg.sender] = block.timestamp - 1 days;
            lastTime = lastClaim[msg.sender];
        }

        uint256 timePassed = block.timestamp - lastTime;
        uint256 daysPassed = timePassed / 1 days;

        require(daysPassed > 0, "Too early");

        uint256 reward = daysPassed * dailyReward;

        // Max claim limit
        if (reward > maxClaimPerTx) {
            reward = maxClaimPerTx;
        }

        // ✅ balance check AFTER reward calculate
        require(balanceOf[address(this)] >= reward, "No reward balance");

        // update time properly
        lastClaim[msg.sender] += (reward / dailyReward) * 1 days;

        _transfer(address(this), msg.sender, reward);
    }
    function setMinHolding(uint256 amount) external onlyOwner {
        minHolding = amount;
    }

    function setDailyReward(uint256 amount) external onlyOwner {
        dailyReward = amount;
    }

    function setMaxClaimPerTx(uint256 amount) external onlyOwner {
        maxClaimPerTx = amount;
    }

    function setClaimEnabled(bool status) external onlyOwner {
        claimEnabled = status;
    }

    function setWallets(
        address _dev,
        address _marketing,
        address _foundation,
        address _liquidity
    ) external onlyOwner {
        devWallet = _dev;
        marketingWallet = _marketing;
        mpsFoundation = _foundation;
        liquidityWallet = _liquidity;
    }

    function setBuyTax(
        uint256 d,
        uint256 m,
        uint256 c,
        uint256 l
    ) external onlyOwner {
        require(d + m + c + l <= 25, "Too high");
        buyTax = Tax(d, m, c, l);
    }

    function setSellTax(
        uint256 d,
        uint256 m,
        uint256 c,
        uint256 l
    ) external onlyOwner {
        require(d + m + c + l <= 25, "Too high");
        sellTax = Tax(d, m, c, l);
    }
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(balanceOf[from] >= amount, "Balance low");

        uint256 amountAfterTax = amount;

        // 🔥 detect buy / sell
        bool isBuy = from == address(router);
        bool isSell = to == address(router);

        Tax memory tax;

        if (isBuy) {
            tax = buyTax;
        } else if (isSell) {
            tax = sellTax;
        } else {
            tax = buyTax; // normal transfer
        }

        // ================= TAX =================
        if (!isFeeExempt[from] && !isFeeExempt[to]) {
            uint256 devAmount = (amount * tax.dev) / 100;
            uint256 marketingAmount = (amount * tax.marketing) / 100;
            uint256 charityAmount = (amount * tax.charity) / 100;
            uint256 liquidityAmount = (amount * tax.liquidity) / 100;

            if (devAmount > 0) super._transfer(from, devWallet, devAmount);
            if (marketingAmount > 0)
                super._transfer(from, marketingWallet, marketingAmount);
            if (charityAmount > 0)
                super._transfer(from, mpsFoundation, charityAmount);
            if (liquidityAmount > 0)
                super._transfer(from, liquidityWallet, liquidityAmount);

            amountAfterTax -= (devAmount +
                marketingAmount +
                charityAmount +
                liquidityAmount);
        }

        // ================= MAIN TRANSFER =================
        super._transfer(from, to, amountAfterTax);

        // 🔥 optional: reset claim if balance low
        if (balanceOf[from] < minHolding) {
            lastClaim[from] = block.timestamp;
        }

        // 🔥 optional: start timer for new holders
        if (balanceOf[to] >= minHolding && lastClaim[to] == 0) {
            lastClaim[to] = block.timestamp;
        }
    }
    // ================= CLAIM (BACKEND ONLY) =================
    function claim(address user, uint256 amount) external {
        require(claimEnabled, "Claim off");
        require(msg.sender == backendWallet, "Only backend");
        require(balanceOf[address(this)] >= amount, "Not enough tokens");

        _transfer(address(this), user, amount);
    }
    // ================= WITHDRAW =================
    function withdrawBNB() external onlyOwner {
        (bool success, ) = payable(owner).call{value: address(this).balance}(
            ""
        );
        require(success, "Transfer failed");
    }
    function withdrawUSDT(uint256 amount) external onlyOwner {
        require(usdtToken != address(0), "USDT not set");
        IERC20(usdtToken).transfer(owner, amount);
    }
    function withdrawAllToken() external onlyOwner {
        uint256 balance = balanceOf[address(this)];
        require(balance > 0, "No tokens");

        _transfer(address(this), owner, balance);
    }

    receive() external payable {}
}
