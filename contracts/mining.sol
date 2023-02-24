// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";



contract mining {
    using SafeERC20 for IERC20;
    // HEY
    address public immutable HEY = address(0x07bB4B361e903dB80Bce1F18246303DFd3b2600A);

    // 所有矿池
    mapping(uint256 => PoolInfo) public Pools;

    // 矿池数量
    uint256 public poolsLength = 0;

    // 质押记录
    mapping(uint256 => mapping(uint256 => StakeInfo)) public Records;

    // 用户质押信息
    mapping(uint256 => mapping(address => UserStakeInfo)) public StakingUsers;

    // token精度
    uint8 decimal = 0;

    struct PoolInfo {
        // 池ID
        uint256 miningId;
        // 可质押的token
        string symbol;
        // 可质押token地址
        address tokenAddress;
        // 质押的总量
        uint256 total;
        // 质押笔数
        uint256 stakingNum;
        // 矿池收益率（百分比）
        uint256 rate;
    }

    struct StakeInfo {
        // 池ID
        uint256 miningId;
        // 质押账户地址
        address userAddress;
        // 质押地址
        address tokenAddress;
        // 质押时间
        uint256 stakeTime;
        // 质押数量
        uint256 amount;
    }

    struct UserStakeInfo {
        // 是否质押过
        bool isStaking;
        // 已领取奖励数量
        uint256 alreadyWithdrawAmount;
        // 用户质押总量
        uint256 stakingTotal;
        // 质押时间
        uint256 stakingTime;
    }

    // 检查矿池是否存在
    modifier onlyExisted(uint256 _miningId) {
        require(Pools[_miningId].miningId >= 0, "mining not existed!");
        _;
    }

    constructor() {
        addPool(0, "BNB", address(0), 0, 0, 10);
        addPool(1, "HEY", HEY, 0, 0, 1);

        decimal = IERC20Metadata(HEY).decimals();
    }

    // 添加矿池
    function addPool(
        uint256 _miningId,
        string memory _symbol,
        address _tokenAddress,
        uint256 _total,
        uint256 _stakingNum,
        uint256 _rate
    ) internal {
        Pools[_miningId] = PoolInfo({
            miningId: _miningId,
            symbol: _symbol,
            tokenAddress: _tokenAddress,
            total: _total,
            stakingNum: _stakingNum,
            rate: _rate
        });
        poolsLength++;
    }

    event Staking(uint256 _miningId, address user, uint256 amount);

    event Log(string name, uint256 value);

    event Withdraw(uint256 _miningId, address user, uint256 reward);

    // 质押BNB
    function stakingBNB(uint256 _miningId)
        external
        payable
        onlyExisted(_miningId)
    {
        PoolInfo storage poolinfo = Pools[_miningId];
        require(poolinfo.tokenAddress == address(0), "The staking BNB!");
        uint256 amount = uint256(msg.value);
        poolinfo.total += amount;
        poolinfo.stakingNum += 1;
        emit Staking(_miningId, msg.sender, amount);
        addRecords(
            _miningId,
            poolinfo.stakingNum,
            msg.sender,
            poolinfo.tokenAddress,
            amount
        );
        addUserStakingInfo(_miningId, msg.sender, amount);
    }

    // 质押token
    function stakingToken(
        uint256 _miningId,
        address _tokenAddress,
        uint256 _amount
    ) external onlyExisted(_miningId) {
        require(_amount > 0, "Staking Amount Error!");
        PoolInfo storage poolinfo = Pools[_miningId];
        require(poolinfo.tokenAddress != address(0), "The staking Token!");
        IERC20(_tokenAddress).transferFrom(msg.sender, address(this), _amount);
        poolinfo.total += _amount;
        poolinfo.stakingNum += 1;
        emit Staking(_miningId, msg.sender, _amount);
        addRecords(
            _miningId,
            poolinfo.stakingNum,
            msg.sender,
            poolinfo.tokenAddress,
            _amount
        );
        addUserStakingInfo(_miningId, msg.sender, _amount);
    }

    // 添加质押记录
    function addRecords(
        uint256 _miningId,
        uint256 _index,
        address _userAddress,
        address _tokenAddress,
        uint256 _amount
    ) internal {
        Records[_miningId][_index] = StakeInfo({
            miningId: _miningId,
            userAddress: _userAddress,
            tokenAddress: _tokenAddress,
            stakeTime: block.timestamp,
            amount: _amount
        });
    }

    // 添加用户质押信息
    function addUserStakingInfo(
        uint256 _miningId,
        address _userAddress,
        uint256 _amount
    ) internal {
        bool isStaking = StakingUsers[_miningId][_userAddress].isStaking;
        if (isStaking) {
            UserStakeInfo storage userStakeInfo = StakingUsers[_miningId][
                _userAddress
            ];
            userStakeInfo.stakingTotal += _amount;
        } else {
            StakingUsers[_miningId][_userAddress] = UserStakeInfo({
                isStaking: true,
                alreadyWithdrawAmount: 0,
                stakingTotal: _amount,
                stakingTime: block.timestamp
            });
        }
    }

    //

    // 计算收益
    function getReward(uint256 _miningId) public view returns (uint256) {
        uint256 rate = Pools[_miningId].rate;   // 收益率（百分比）
        uint256 timeDifference = block.timestamp - StakingUsers[_miningId][msg.sender].stakingTime; // 已质押时间
        uint256 minuteDifference = timeDifference / 60; // 已质押分钟
        uint256 userStakingTotal = StakingUsers[_miningId][msg.sender].stakingTotal; // 用户该矿池质押总量
        uint256 totalReward = userStakingTotal * rate * minuteDifference / 100;
        uint256 alreadyWithdrawAmount = StakingUsers[_miningId][msg.sender].alreadyWithdrawAmount;
        uint256 reward = totalReward - alreadyWithdrawAmount;
        return reward;
    }

    
    // 领取收益
    function withdraw(uint256 _miningId) external onlyExisted(_miningId){
        uint256 reward = getReward(_miningId);
        bool success = IERC20(HEY).transfer(msg.sender, reward);
        if(success){
            StakingUsers[_miningId][msg.sender].alreadyWithdrawAmount += reward;
        }
        emit Withdraw(_miningId, msg.sender, reward);
    }

    function getTokenBalance(address _tokenAddress) external view returns (uint256) {
        // string memory decimal = IERC20Metadata(HEY).name();
        // return decimal;
        // uint8 decimal = IERC20Metadata(HEY).decimals();
        // return decimal;
        uint256 total = IERC20(_tokenAddress).balanceOf(address(this));
        return total;
    }
}
