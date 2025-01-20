// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0 <0.9.0;

contract Payroll {
    address public companyAcc;
    uint256 public companyBal;
    uint256 public totalEmployees = 0;
    uint256 public totalSalary = 0;
    uint256 public lastPaymentTime; // Time of last payment
    uint256 public paymentInterval = 30 days; // Example payment interval (can be modified)
    
    mapping(address => bool) isEmployee;
    mapping(address => uint256) public lastPaid;

    event Paid(uint256 id, address from, uint256 totalSalary, uint256 timestamp);
    event EmployeeAdded(uint256 id, address worker, uint256 salary);
    event EmployeeDeactivated(uint256 id, address worker, uint256 timestamp);
    event PaymentScheduled(uint256 nextPaymentTime);
    event CompanyFunded(address from, uint256 amount, uint256 newBalance);
    event PaymentIntervalUpdated(uint256 newInterval);

    struct Employee {
        uint256 id;
        address worker;
        uint256 salary;
        uint256 timestamp;
        bool isActive;
    }

    Employee[] employees;

    modifier onlyCompanyOwner() {
        require(msg.sender == companyAcc, "Only company owner can perform this action");
        _;
    }

    modifier onlyActiveEmployees() {
        require(isEmployee[msg.sender] && employees[getEmployeeIndex(msg.sender)].isActive, "Only active employees can access this");
        _;
    }

    constructor() {
        companyAcc = msg.sender;
        lastPaymentTime = block.timestamp; // Set the initial payment time to now
    }

    function addEmployee(address _worker, uint256 _salary) external onlyCompanyOwner {
        require(!isEmployee[_worker], "Employee already exists");
        uint256 id = employees.length;
        employees.push(Employee(id, _worker, _salary, block.timestamp, true));
        isEmployee[_worker] = true;
        totalEmployees++;
        totalSalary += _salary;
        emit EmployeeAdded(id, _worker, _salary);
    }

    function deactivateEmployee(address _worker) external onlyCompanyOwner {
        uint256 index = getEmployeeIndex(_worker);
        require(employees[index].isActive, "Employee is already inactive");
        employees[index].isActive = false;
        totalSalary -= employees[index].salary;
        emit EmployeeDeactivated(employees[index].id, _worker, block.timestamp);
    }

    function fundCompanyBalance() external payable {
        require(msg.sender != companyAcc, "Company owner cannot fund directly");
        companyBal += msg.value;
        emit CompanyFunded(msg.sender, msg.value, companyBal);
    }

    function updatePaymentInterval(uint256 _newInterval) external onlyCompanyOwner {
        require(_newInterval > 0, "Payment interval must be greater than 0");
        paymentInterval = _newInterval;
        emit PaymentIntervalUpdated(_newInterval);
    }

    function payEmployees() external onlyCompanyOwner {
        require(block.timestamp >= lastPaymentTime + paymentInterval, "Payment interval has not elapsed");
        require(companyBal >= totalSalary, "Insufficient company balance");
        
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i].isActive) {
                _sendPayment(employees[i].worker, employees[i].salary);
                lastPaid[employees[i].worker] = block.timestamp;
            }
        }

        lastPaymentTime = block.timestamp;
        emit Paid(block.timestamp, msg.sender, totalSalary, block.timestamp);
        emit PaymentScheduled(lastPaymentTime + paymentInterval);
    }

    function getEmployees() external view returns (Employee[] memory) {
        return employees;
    }

    function terminateContract() external onlyCompanyOwner {
        selfdestruct(payable(companyAcc));
    }

    function getEmployeeIndex(address _worker) internal view returns (uint256) {
        for (uint256 i = 0; i < employees.length; i++) {
            if (employees[i].worker == _worker) {
                return i;
            }
        }
        revert("Employee not found");
    }

    function _sendPayment(address _to, uint256 _amount) internal {
        require(address(this).balance >= _amount, "Insufficient contract balance");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Payment failed");
        companyBal -= _amount;
    }
}
