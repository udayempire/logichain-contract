// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/escrow.sol";

contract MockERC20 is IERC20 {
    string public name = "MockToken";
    string public symbol = "MCK";
    uint8 public decimals = 18;
    uint256 public totalSupply = 1_000_000 ether;

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(address initialHolder) {
        balanceOf[initialHolder] = totalSupply;
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        require(balanceOf[msg.sender] >= amount, "insufficient");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        require(balanceOf[from] >= amount, "insufficient");
        require(allowance[from][msg.sender] >= amount, "not allowed");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        return true;
    }
}

contract EscrowTest is Test {
    Escrow public escrow;
    MockERC20 public token;

    address buyer = address(0xBEEF);
    address supplier = address(0xCAFE);

    function setUp() public {
        // Deploy token, mint all supply to buyer
        token = new MockERC20(buyer);

        // Deploy escrow with token address
        escrow = new Escrow(address(token));

        // Label addresses for readability in logs
        vm.label(buyer, "Buyer");
        vm.label(supplier, "Supplier");
    }

    function testCreateAndReleaseOrder() public {
        uint256 amount = 100 ether;
        bytes32 orderId = keccak256("ship-1001");

        // Buyer approves escrow contract
        vm.startPrank(buyer);
        token.approve(address(escrow), amount);

        // Create order
        escrow.createOrder(orderId, supplier, amount);

        (address orderBuyer, address orderSupplier, uint256 orderAmount, Escrow.Status orderStatus, uint256 createdAt) = escrow.orders(orderId);
        assertEq(orderAmount, amount);
        assertEq(orderBuyer, buyer);
        assertEq(orderSupplier, supplier);
        assertEq(uint(orderStatus), uint(Escrow.Status.Funded));

        // Confirm balances
        assertEq(token.balanceOf(address(escrow)), amount);
        assertEq(token.balanceOf(buyer), token.totalSupply() - amount);

        // Buyer confirms delivery
        escrow.confirmDelivery(orderId);

        // Supplier should now have funds
        assertEq(token.balanceOf(supplier), amount);

        // Order status should be Released
        (, , , orderStatus, ) = escrow.orders(orderId);
        assertEq(uint(orderStatus), uint(Escrow.Status.Released));

        vm.stopPrank();
    }

    function testOnlyBuyerCanRelease() public {
        uint256 amount = 50 ether;
        bytes32 orderId = keccak256("ship-1002");

        vm.startPrank(buyer);
        token.approve(address(escrow), amount);
        escrow.createOrder(orderId, supplier, amount);
        vm.stopPrank();

        // Supplier tries to release (should fail)
        vm.prank(supplier);
        vm.expectRevert("only buyer");
        escrow.confirmDelivery(orderId);
    }

    function testCannotDoubleCreateOrder() public {
        uint256 amount = 25 ether;
        bytes32 orderId = keccak256("ship-1003");

        vm.startPrank(buyer);
        token.approve(address(escrow), amount * 2);
        escrow.createOrder(orderId, supplier, amount);

        vm.expectRevert("exists");
        escrow.createOrder(orderId, supplier, amount);
        vm.stopPrank();
    }
}
