#include <iostream>
#include <string>
#include <vector>
#include <stdexcept>
#include <mysql_driver.h>
#include <mysql_connection.h>
#include <cppconn/statement.h>
#include <cppconn/prepared_statement.h>
#include <cppconn/resultset.h>
#include <cppconn/exception.h>

using namespace std;
using namespace sql;

void mainMenu(Connection *con);
void insertStudent(Connection *con);
void deleteStudent(Connection *con);
void showStudents(Connection *con);
void addColumn(Connection *con);
void removeColumn(Connection *con);
void updateColumn(Connection *con);

int main() {
    try {
        mysql::MySQL_Driver *driver;
        Connection *con;
        
        driver = mysql::get_mysql_driver_instance();
        con = driver->connect("tcp://127.0.0.1:3306", "souvik", "souvik@2001");
        con->setSchema("student");

        mainMenu(con);

        delete con;
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
        return 1;
    }

    return 0;
}

void mainMenu(Connection *con) {
    int choice;
    do {
        cout << "Enter 1 to insert new Records of students." << endl;
        cout << "Enter 2 to Remove any records by student Roll No." << endl;
        cout << "Enter 3 to Show records of existing students." << endl;
        cout << "Enter 4 for add new Student's Attribute." << endl;
        cout << "Enter 5 for remove Student's Attribute." << endl;
        cout << "Enter 6 for update value of any student's attribute." << endl;
        cout << "Enter 7 to exit." << endl;
        cin >> choice;

        switch (choice) {
            case 1:
                insertStudent(con);
                break;
            case 2:
                deleteStudent(con);
                break;
            case 3:
                showStudents(con);
                break;
            case 4:
                addColumn(con);
                break;
            case 5:
                removeColumn(con);
                break;
            case 6:
                updateColumn(con);
                break;
            case 7:
                cout << "Bye..." << endl;
                break;
            default:
                cout << "Try again....." << endl;
        }
    } while (choice != 7);
}

void insertStudent(Connection *con) {
    try {
        unique_ptr<Statement> stmt(con->createStatement());
        unique_ptr<ResultSet> res(stmt->executeQuery("SELECT Attribute_Name FROM Attributes_Details;"));

        vector<string> attributes_name;
        while (res->next()) {
            attributes_name.push_back(res->getString("Attribute_Name"));
        }

        vector<string> attributes_values;
        for (const auto &attribute : attributes_name) {
            string value;
            cout << "Enter " << attribute << " of the student: ";
            cin >> value;
            attributes_values.push_back(value);
        }

        string query = "INSERT INTO student (";
        for (const auto &attribute : attributes_name) {
            query += attribute + ", ";
        }
        query.pop_back(); // remove last comma
        query.pop_back();
        query += ") VALUES (";
        for (size_t i = 0; i < attributes_name.size(); ++i) {
            query += "?, ";
        }
        query.pop_back();
        query.pop_back();
        query += ")";

        unique_ptr<PreparedStatement> pstmt(con->prepareStatement(query));
        for (size_t i = 0; i < attributes_values.size(); ++i) {
            pstmt->setString(i + 1, attributes_values[i]);
        }
        pstmt->execute();
        cout << "Student details saved....." << endl;
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}

void deleteStudent(Connection *con) {
    try {
        string roll_no;
        cout << "Enter Student Roll No to remove this student: ";
        cin >> roll_no;

        string query = "DELETE FROM student WHERE RollNo=?";
        unique_ptr<PreparedStatement> pstmt(con->prepareStatement(query));
        pstmt->setString(1, roll_no);
        pstmt->execute();

        cout << "Student details removed....." << endl;
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}

void showStudents(Connection *con) {
    try {
        unique_ptr<Statement> stmt(con->createStatement());
        unique_ptr<ResultSet> res(stmt->executeQuery("SELECT * FROM student;"));

        ResultSetMetaData *meta = res->getMetaData();
        int numCols = meta->getColumnCount();

        // Print column names
        for (int i = 1; i <= numCols; ++i) {
            cout << meta->getColumnName(i) << "\t";
        }
        cout << endl;

        // Print rows
        while (res->next()) {
            for (int i = 1; i <= numCols; ++i) {
                cout << res->getString(i) << "\t";
            }
            cout << endl;
        }
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}

void addColumn(Connection *con) {
    try {
        string column, data_type, size, nullable;
        cout << "Enter New column or attribute name: ";
        cin >> column;
        cout << "Enter column data type: ";
        cin >> data_type;
        cout << "Do you want to make this attribute NULL able or Not. For yes Enter y & for no enter n: ";
        cin >> nullable;

        string query = "ALTER TABLE student ADD COLUMN " + column + " " + data_type;
        if (data_type == "varchar" || data_type == "char") {
            cout << "Enter Size of " << data_type << " data type: ";
            cin >> size;
            query += "(" + size + ")";
        }
        if (nullable == "n") {
            query += " NOT NULL";
        }

        unique_ptr<Statement> stmt(con->createStatement());
        stmt->execute(query);

        query = "INSERT INTO Attributes_Details VALUES (?, ?)";
        unique_ptr<PreparedStatement> pstmt(con->prepareStatement(query));
        pstmt->setString(1, column);
        pstmt->setString(2, data_type);
        pstmt->execute();

        cout << "New attribute added.....\nNow insert new values for newly added Attribute....." << endl;
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}

void removeColumn(Connection *con) {
    try {
        string column;
        cout << "Enter attribute name want to remove: ";
        cin >> column;

        string query = "ALTER TABLE student DROP COLUMN " + column;
        unique_ptr<Statement> stmt(con->createStatement());
        stmt->execute(query);

        query = "DELETE FROM Attributes_Details WHERE Attribute_Name=?";
        unique_ptr<PreparedStatement> pstmt(con->prepareStatement(query));
        pstmt->setString(1, column);
        pstmt->execute();

        cout << "Attribute removed....." << endl;
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}

void updateColumn(Connection *con) {
    try {
        string column, new_value, roll_no;
        cout << "Enter Attribute name want to update: ";
        cin >> column;

        string query = "SELECT Data_Type FROM Attributes_Details WHERE Attribute_Name=?";
        unique_ptr<PreparedStatement> pstmt(con->prepareStatement(query));
        pstmt->setString(1, column);
        unique_ptr<ResultSet> res(pstmt->executeQuery());

        if (res->next()) {
            string data_type = res->getString("Data_Type");
            cout << "Enter new value: ";
            cin >> new_value;
            cout << "Enter student Roll No want to update: ";
            cin >> roll_no;

            query = "UPDATE student SET " + column + "=? WHERE RollNo=?";
            pstmt.reset(con->prepareStatement(query));
            if (data_type == "varchar" || data_type == "char") {
                pstmt->setString(1, new_value);
            } else {
                pstmt->setInt(1, stoi(new_value));
            }
            pstmt->setString(2, roll_no);
            pstmt->execute();

            cout << "Student details updated....." << endl;
        }
    } catch (SQLException &e) {
        cerr << "SQLException: " << e.what() << endl;
    }
}
