// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Імпорт стандартів та утиліт безпеки з OpenZeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title SalaryStream
 * @dev Контракт для стрімінгу зарплати працівнику. Роботодавець депонує кошти,
 * а працівник може забирати їх пропорційно часу, що минув.
 */
contract SalaryStream is Ownable, ReentrancyGuard {
    // Використовуємо безпечні операції для ERC20 (особливо важливо для USDT)
    using SafeERC20 for IERC20;

    // Змінні стану
    IERC20 public immutable token;
    address public immutable employee;
    uint256 public immutable startTime;
    uint256 public immutable duration;

    uint256 public totalSalary;
    uint256 public released;

    // Події для відстеження в блокчейні
    event Deposited(address indexed employer, uint256 amount);
    event Withdrawn(address indexed employee, uint256 amount);

    /**
     * @param _token Адреса токена (наприклад, USDT)
     * @param _employee Адреса працівника
     * @param _startTime Час початку стрімінгу (Unix Timestamp)
     * @param _duration Тривалість контракту в секундах (наприклад, 30 днів = 2592000)
     */
    constructor(
        address _token,
        address _employee,
        uint256 _startTime,
        uint256 _duration
    ) Ownable(msg.sender) {
        require(_token != address(0), "Invalid token address");
        require(_employee != address(0), "Invalid employee address");
        require(_duration > 0, "Duration must be > 0");

        token = IERC20(_token);
        employee = _employee;
        startTime = _startTime == 0 ? block.timestamp : _startTime;
        duration = _duration;
    }

    /**
     * @dev Роботодавець (власник) депонує зарплату. 
     * Перед викликом роботодавець має зробити token.approve() для цього контракту.
     */
    function deposit(uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be > 0");
        
        totalSalary += amount;
        
        // Взаємодія з токеном
        token.safeTransferFrom(msg.sender, address(this), amount);
        
        emit Deposited(msg.sender, amount);
    }

    /**
     * @dev Працівник викликає цю функцію для зняття доступної частини зарплати.
     */
    function withdraw() external nonReentrant {
        // 1. Checks (Перевірки)
        require(msg.sender == employee, "Only employee can withdraw");
        
        uint256 unreleased = vestedAmount() - released;
        require(unreleased > 0, "Nothing to withdraw");

        // 2. Effects (Ефекти - оновлення стану ДО взаємодії)
        released += unreleased;

        // 3. Interactions (Взаємодія зі стороннім контрактом)
        token.safeTransfer(employee, unreleased);

        emit Withdrawn(employee, unreleased);
    }

    /**
     * @dev Обчислює загальну суму, яка вже "зароблена" (розблокована) на поточний момент.
     * Тут реалізовано математику з плаваючою крапкою для Solidity.
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < startTime) {
            return 0;
        } else if (block.timestamp >= startTime + duration) {
            return totalSalary;
        } else {
            // МАТЕМАТИКА: Завжди спочатку множимо, а потім ділимо!
            // Це нівелює проблему відсутності дробових чисел (float) у Solidity.
            return (totalSalary * (block.timestamp - startTime)) / duration;
        }
    }

    /**
     * @dev Показує, скільки токенів працівник може зняти прямо зараз.
     */
    function getAvailableAmount() external view returns (uint256) {
        return vestedAmount() - released;
    }
}
