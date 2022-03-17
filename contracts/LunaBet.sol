// SPDX-License-Identifier: MIT
// LunaBet

pragma solidity ^0.8.11;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract LunaBet {
  address payable public immutable lunaBear;
  address payable public immutable lunaBull;
  address public immutable cobie;

  uint256 public immutable betEndDate;
  uint256 public immutable startPrice;

  AggregatorV3Interface internal lunaPriceFeed;

  /** -----------------------------------------------------------------------------
   *   Contract event definitions
   *   -----------------------------------------------------------------------------
   */
  event BetConcluded(
    address winner,
    address loser,
    uint256 payout,
    string message
  );

  event BetFunded(
    address funder,
    uint256 amount
  );

  event BalanceClearedAfterGracePeriod(
    uint256 indexed withdrawal, 
    address indexed withdrawer
  );

  event CurrentLunaPrice(
    uint80 roundID,
    int256 price,
    uint256 startedAt,
    uint256 timeStamp,
    uint80 answeredInRound
  );

  constructor(
    address payable _cobie,
    address payable _lunaBear,
    address payable _lunaBull,
    uint256 _betDurationInDays,
    address _priceFeed

  ) {
    lunaBear = _lunaBear;
    lunaBull = _lunaBull;
    cobie = _cobie;

    lunaPriceFeed = AggregatorV3Interface(_priceFeed);

    betEndDate = block.timestamp + (_betDurationInDays * 24 hours);

    startPrice = uint256(getLatestPrice());
  }

  modifier onlyBetParticipants(address _from) {
    require ((_from == cobie || _from == lunaBear || _from == lunaBull), "Only parties to the bet can do this.");
    _;
  }

  receive() external payable onlyBetParticipants(msg.sender) {
    emit BetFunded(msg.sender, msg.value);
  }

  fallback() external payable {
    revert();
  }

  function getLatestPrice() internal returns (int256) {
    (
      uint80 roundID,
      int256 price,
      uint256 startedAt,
      uint256 timeStamp,
      uint80 answeredInRound
    ) = lunaPriceFeed.latestRoundData();
    emit CurrentLunaPrice(roundID, price, startedAt, timeStamp, answeredInRound);
    return price;
  }

  function payoutTheBet(uint256 _winnings) external onlyBetParticipants(msg.sender)  {
    require(block.timestamp >= betEndDate, "Bet hasn't finished. Patience...");

    if (uint256(getLatestPrice()) > startPrice) {
      // Bulls win:
      (bool success, ) = lunaBull.call{value: _winnings}("");
      require(success, "Transfer failed.");
      emit BetConcluded(lunaBull, lunaBear, _winnings, "Luna rules!");
    }
    else {
      // Bears win:
      (bool success, ) = lunaBear.call{value: _winnings}("");
      require(success, "Transfer failed.");
      emit BetConcluded(lunaBull, lunaBear, _winnings, "Luna sucks!");
      // yeah if price is exactly the same bears win too. 
    }
  }

  function breakGlassInCaseOfEmergency(uint256 _withdrawal) external onlyBetParticipants(msg.sender) {
    // 90 days after the end date let any party to the bet can clear the balance. Assumption is that the winner
    // has had time to exercise prior rights through payoutTheBet and this function protects against total pricefeed
    // failure and/or participant death.
    require(block.timestamp >= (betEndDate + (90 * 24 hours)) , "Winner has time to exercise rights. Patience...");

    (bool success, ) = msg.sender.call{value: _withdrawal}("");
    require(success, "Transfer failed.");
    emit BalanceClearedAfterGracePeriod(_withdrawal, msg.sender);
  }
}