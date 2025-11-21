// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test, console} from "../../lib/forge-std/src/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("user");
    uint256 constant SEND_VALUE = 0.1 ether; //0.1 ETH
    uint256 constant STARTING_BALANCE = 10 ether; //10 ETH
    // uint256 constant GAS_PRICE = 1; //1 gwei

    function setUp() external {
        // fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE); //Give USER some ETH
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public view {
        uint256 version = fundMe.getVersion();
        if (block.chainid == 11155111) {
            assertEq(version, 4);
        } else if (block.chainid == 1) {
            assertEq(version, 6);
        } else {
            assertEq(version, 4);
        }
    }

    function testFundFailsWithoutEnoughETH() public {
        vm.expectRevert(); //The next line should revert
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        vm.prank(USER); //The next tx will be sent by USER
        // fundMe.fund{value: 10e18}();
        // uint256 amountFunded = fundMe.getAddressToAmountFunded(address(this)); // address(this) is the test contract (fundMe) which called fund()
        fundMe.fund{value: SEND_VALUE}();
        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER); // address(this) is the test contract (fundMe) which called fund()
        // assertEq(amountFunded, 10e18);
        assertEq(amountFunded, SEND_VALUE);
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunder(0); //setUp is run before every test (so fund calls in other tests do not affect this)
        assertEq(funder, USER);
    }

    modifier funded() {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        // vm.prank(USER);
        // fundMe.fund{value: SEND_VALUE}();

        vm.expectRevert();
        vm.prank(USER); //Ignored by the vm.expectRevert()
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        //Arrange
        uint256 startingFundMeBalance = address(fundMe).balance; //USER sent funds to the contract in the funded() modifier
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        //Act
        // uint256 gasStart = gasleft(); //How much gas is left in the tx call - this is a solidity function
        // vm.txGasPrice(GAS_PRICE);
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();
        // uint256 gasEnd = gasleft();
        // uint256 gasUsed = gasStart - gasEnd;
        // uint256 gasCost = gasUsed * GAS_PRICE;
        // console.log(gasCost);

        //Assert
        uint256 endingFundMeBalance = address(fundMe).balance;
        uint256 endingOwnerBalance = fundMe.getOwner().balance;

        assertEq(endingFundMeBalance, 0);
        assertEq(
            startingFundMeBalance + startingOwnerBalance,
            endingOwnerBalance
        );
    }

    function testWithdrawFromMultipleFunders() public funded {
        //Arrange
        uint160 numberOfFunders = 10; //Needed to create addresses from number
        uint160 startingFunderIndex = 1;
        for (uint160 i = startingFunderIndex; i < numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        uint256 startingFundMeBalance = address(fundMe).balance;
        uint256 startingOwnerBalance = fundMe.getOwner().balance;

        //Act
        vm.startPrank(fundMe.getOwner());
        fundMe.withdraw();
        vm.stopPrank();

        //Assert
        assert(address(fundMe).balance == 0);
        assert(
            startingFundMeBalance + startingOwnerBalance ==
                fundMe.getOwner().balance
        );
    }
}
