// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Escrow is ReentrancyGuard, Ownable {
    enum Status { None, Funded, Released, Cancelled }

    struct Order {
        address buyer;
        address supplier;
        uint256 amount;
        Status status;
        uint256 createdAt;
    }

    IERC20 public immutable paymentToken;
    mapping(bytes32 => Order) public orders;

    event OrderCreated(bytes32 indexed orderId, address indexed buyer, address indexed supplier, uint256 amount);
    event OrderReleased(bytes32 indexed orderId, address indexed supplier, uint256 amount);

    constructor(address _paymentToken) Ownable(msg.sender) {
        require(_paymentToken != address(0), "token zero");
        paymentToken = IERC20(_paymentToken);
    }

    function createOrder(bytes32 orderId, address supplier, uint256 amount) external nonReentrant {
        require(orderId != bytes32(0), "invalid id");
        require(orders[orderId].status == Status.None, "exists");
        bool ok = paymentToken.transferFrom(msg.sender, address(this), amount);
        require(ok, "transferFrom failed");
        orders[orderId] = Order(msg.sender, supplier, amount, Status.Funded, block.timestamp);
        emit OrderCreated(orderId, msg.sender, supplier, amount);
    }

    function confirmDelivery(bytes32 orderId) external nonReentrant {
        Order storage o = orders[orderId];
        require(o.status == Status.Funded, "not funded");
        require(msg.sender == o.buyer, "only buyer");
        o.status = Status.Released;
        bool ok = paymentToken.transfer(o.supplier, o.amount);
        require(ok, "transfer failed");
        emit OrderReleased(orderId, o.supplier, o.amount);
    }
}
