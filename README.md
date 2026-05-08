# Зарплатний стрімінг

Цей проєкт реалізує смарт-контракт для **децентралізованого стрімінгу зарплати** (Salary Streaming). Роботодавець депонує суму в токенах ERC20 (наприклад, USDT), а працівник отримує можливість знімати свою зарплату частинами, пропорційно часу, що минув з початку місяця (з точністю до секунди).



## Встановлення та запуск локально (Foundry)

### 1. Передумови
Переконайтеся, що у вас встановлено [Foundry](https://book.getfoundry.sh/getting-started/installation). Якщо ні, виконайте команду:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Клонування та налаштування
Створіть папку проєкту, ініціалізуйте Foundry та встановіть залежності OpenZeppelin:
```bash
forge init salary-stream
cd salary-stream
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

*Примітка: Переконайтеся, що у вашому `foundry.toml` додано ремаппінг для OpenZeppelin:*
```toml
remappings = ['@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/']
```

### 3. Компіляція
```bash
forge build
```
