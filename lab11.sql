DROP TABLE EmpDeptChangeHistory
DROP TRIGGER audit

CREATE TABLE EmpDeptChangeHistory(
    emp_no INT NOT NULL FOREIGN KEY REFERENCES employee(emp_no),
    old_dept_no CHAR(4) NOT NULL FOREIGN KEY REFERENCES department(dept_no),
    new_dept_no CHAR(4) NOT NULL FOREIGN KEY REFERENCES department(dept_no),
    change_dt DATETIME NOT NULL DEFAULT GETDATE(),
    PRIMARY KEY (emp_no, change_dt)
)
GO

CREATE TRIGGER audit
ON [dbo].employee
AFTER UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM INSERTED i
        JOIN DELETED d ON i.emp_no = d.emp_no
        WHERE i.dept_no <> d.dept_no
    )
    BEGIN
        INSERT INTO EmpDeptChangeHistory (emp_no, old_dept_no, new_dept_no)
        SELECT 
            d.emp_no,
            d.dept_no,
            i.dept_no
        FROM INSERTED i
        JOIN DELETED d ON i.emp_no = d.emp_no
        WHERE i.dept_no <> d.dept_no;
    END
END;
GO

UPDATE employee
SET dept_no = 'D3'
WHERE emp_no = 15000
GO
UPDATE employee
SET dept_no = 'D1'
WHERE emp_no = 15000
GO
UPDATE employee
SET emp_fname = 'Flo'
WHERE emp_no = 15000
GO

SELECT * FROM EmpDeptChangeHistory

