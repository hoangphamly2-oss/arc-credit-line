// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract CreditLine {
    IERC20 public immutable usdc;
    address public admin;

    struct Line {
        uint256 limit;
        uint256 drawn;
        bool active;
    }
    mapping(address => Line) public lines;
    uint256 public totalDrawn;

    event LineOpened(address indexed borrower, uint256 limit);
    event Drawn(address indexed borrower, uint256 amount);
    event Repaid(address indexed borrower, uint256 amount);
    event LineClosed(address indexed borrower);

    constructor(address _usdc) {
        require(_usdc != address(0), "BAD_USDC");
        usdc = IERC20(_usdc);
        admin = msg.sender;
    }

    modifier onlyAdmin() { require(msg.sender == admin, "NOT_ADMIN"); _; }

    function openLine(address borrower, uint256 limit) external onlyAdmin {
        lines[borrower] = Line(limit, 0, true);
        emit LineOpened(borrower, limit);
    }

    function draw(uint256 amount) external {
        Line storage l = lines[msg.sender];
        require(l.active && l.drawn + amount <= l.limit, "OVER_LIMIT");
        l.drawn += amount;
        totalDrawn += amount;
        require(usdc.transfer(msg.sender, amount), "TRANSFER_FAILED");
        emit Drawn(msg.sender, amount);
    }

    function repay(uint256 amount) external {
        Line storage l = lines[msg.sender];
        require(l.drawn >= amount, "OVER_REPAY");
        require(usdc.transferFrom(msg.sender, address(this), amount), "TRANSFER_FAILED");
        l.drawn -= amount;
        totalDrawn -= amount;
        emit Repaid(msg.sender, amount);
    }

    function closeLine(address borrower) external onlyAdmin {
        require(lines[borrower].drawn == 0, "OUTSTANDING");
        lines[borrower].active = false;
        emit LineClosed(borrower);
    }
}
