// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {SalaryStream} from "../src/SalaryStream.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Створюємо простий Mock-токен для тестів
contract MockUSDT is ERC20 {
    constructor() ERC20("Mock USDT", "USDT") {}
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract SalaryStreamTest is Test {
    SalaryStream public salaryStream;
    MockUSDT public token;

    // Створюємо адреси для ролей
    address public employer = makeAddr("employer");
    address public employee = makeAddr("employee");
    address public stranger = makeAddr("stranger");

    uint256 public constant DURATION = 30 days;
    uint256 public constant TOTAL_SALARY = 1000 * 10**18; // 1000 USDT

    // setUp запускається перед КОЖНИМ тестом
    function setUp() public {
        // Фіксуємо початковий час, щоб уникнути проблем з block.timestamp == 0
        vm.warp(1000000);

        // 1. Деплоїмо токен
        token = new MockUSDT();

        // 2. Деплоїмо SalaryStream від імені роботодавця
        vm.prank(employer);
        salaryStream = new SalaryStream(
            address(token),
            employee,
            block.timestamp,
            DURATION
        );

        // 3. Друкуємо токени роботодавцю та даємо approve контракту
        token.mint(employer, TOTAL_SALARY * 10); // Даємо з запасом
        
        vm.prank(employer);
        token.approve(address(salaryStream), type(uint256).max);
    }

    /* =========================================================
       UNIT ТЕСТИ (Бізнес-логіка)
       ========================================================= */

    function test_CoreBusinessLogic_DepositAndWithdraw() public {
        // 1. Роботодавець депонує гроші
        vm.prank(employer);
        salaryStream.deposit(TOTAL_SALARY);

        assertEq(salaryStream.totalSalary(), TOTAL_SALARY, "Total salary should match deposit");

        // 2. Перемотуємо час на половину місяця (15 днів)
        vm.warp(block.timestamp + 15 days);

        // Працівник повинен мати доступ рівно до 50% суми
        uint256 expectedAvailable = TOTAL_SALARY / 2;
        assertEq(salaryStream.getAvailableAmount(), expectedAvailable, "Should be 50% available");

        // 3. Працівник знімає гроші
        vm.prank(employee);
        salaryStream.withdraw();

        // Перевіряємо баланси після зняття
        assertEq(token.balanceOf(employee), expectedAvailable, "Employee balance should be 50%");
        assertEq(salaryStream.released(), expectedAvailable, "Released amount should update");
        assertEq(salaryStream.getAvailableAmount(), 0, "Available amount should be 0 after withdrawal");

        // 4. Перемотуємо час до кінця контракту
        vm.warp(block.timestamp + 15 days);

        // Знімаємо решту
        vm.prank(employee);
        salaryStream.withdraw();

        assertEq(token.balanceOf(employee), TOTAL_SALARY, "Employee should have received 100% of salary");
    }

    /* =========================================================
       ТЕСТИ КОНТРОЛЮ ДОСТУПУ (Access Control / Security)
       ========================================================= */

    function test_AccessControl_RevertUnauthorizedDeposit() public {
        // Стороння людина або працівник намагається зробити депозит
        vm.prank(stranger);
        
        // Очікуємо, що транзакція впаде з помилкою від модифікатора onlyOwner
        // (У OpenZeppelin v5 це кастомна помилка, у v4 - рядок)
        vm.expectRevert(); 
        salaryStream.deposit(100);
    }

    function test_AccessControl_RevertUnauthorizedWithdraw() public {
        // Роботодавець робить депозит
        vm.prank(employer);
        salaryStream.deposit(TOTAL_SALARY);

        vm.warp(block.timestamp + 10 days);

        // Роботодавець або стороння людина намагається вкрасти зарплату працівника
        vm.prank(stranger);
        vm.expectRevert("Only employee can withdraw");
        salaryStream.withdraw();

        vm.prank(employer);
        vm.expectRevert("Only employee can withdraw");
        salaryStream.withdraw();
    }

    /* =========================================================
       FUZZ ТЕСТИ
       ========================================================= */

    // Foundry автоматично генерує випадкові значення для depositAmount
    function testFuzz_VestedAmountLogic(uint256 depositAmount) public {
        // Обмежуємо випадкове число від 1 wei до 1 мільярда токенів
        // щоб уникнути переповнення загального саплаю токенів (type(uint256).max)
        depositAmount = bound(depositAmount, 1, 1_000_000_000 * 10**18);

        // Даємо роботодавцю саме цю випадкову суму
        token.mint(employer, depositAmount);

        // Роботодавець депонує випадкову суму
        vm.startPrank(employer); // Початок сесії від імені роботодавця
        token.approve(address(salaryStream), depositAmount);
        salaryStream.deposit(depositAmount);
        vm.stopPrank();

        // Перемотуємо час рівно на 30% від усього часу
        uint256 passedTime = (DURATION * 30) / 100;
        vm.warp(block.timestamp + passedTime);

        // Рахуємо очікувану суму: множимо ДО ділення (важливо для Solidity)
        uint256 expectedVested = (depositAmount * passedTime) / DURATION;

        assertEq(
            salaryStream.vestedAmount(), 
            expectedVested, 
            "Fuzz: Vested amount calculation is wrong"
        );
    }
}
