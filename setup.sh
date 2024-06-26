#!/bin/bash

#Function to check a command is present or not
command_exists()
{
	command -v "$1" > /dev/null 2>&1
}

#Function to confirm entered password matched
check_password()
{
	if [ "$1" == "$2" ]; then
		return 0
	else
		return 1
	fi
}


#Creating .env file for python-dotenv package
if [ -f .env ]; then
	rm .env
	touch .env
else
	touch .env
fi


#now adding credentials to .env file created previously
#if [ -f "credential_setup_for_dotenv.py" ]; then
#	python3 credential_setup_for_dotenv.py
#else
#	echo "Error: credential_setup_for_dotenv.py file is missing....."
#	exit 1
#fi
read -p "Enter Mysql Host : " MYSQL_HOST
read -p "Enter Mysql UserName : " MYSQL_USER


while true; do
	read -s -p "Enter Mysql Password : " MYSQL_PASSWORD1
	echo
	read -s -p  "Confirm  Mysql Password : " MYSQL_PASSWORD2
    if check_password "$MYSQL_PASSWORD1" "$MYSQL_PASSWORD2"; then
        MYSQL_PASSWORD="$MYSQL_PASSWORD1"
        break
    else
        echo -e "\nPassword not matched try again"
    fi
done
echo  "MYSQL_HOST=$MYSQL_HOST" >> .env
echo  "MYSQL_USER=$MYSQL_USER" >> .env
echo  "MYSQL_PASSWORD=$MYSQL_PASSWORD" >> .env
rc_file=$(echo $SHELL | awk -F '/' '{print $4}')
rc_file=$(echo "$HOME/.$rc_file""rc")
# Define the file path
file_path="$rc_file"  # Adjust the file path as per your actual file location
# Define the patterns to search for
patterns=("export DB_USER=" "export DB_PASS=")
# Loop through patterns and remove matching lines from the file
for pattern in "${patterns[@]}"; do
    # Use grep to find lines containing the pattern, then use sed to remove them
    if grep -q "$pattern" "$file_path"; then
        echo "Removing line: $pattern"
        sed -i "/$pattern/d" "$file_path"
    else
        echo "Pattern not found: $pattern"
    fi
done
echo -e "export DB_USER=\"$MYSQL_USER\"\nexport DB_PASS=\"$MYSQL_PASSWORD\"" >> "$rc_file"
#checking mysql and python3-venv are present or not if not then try to install them
if command_exists mysql; then
	echo -e "\nMysql Found..\n $(mysql --version)"
	
else
	echo -e "\nMysql not found............."
	echo "Installing mysql server"
	#Ubuntu/Debian:
	if command_exists apt; then
		sudo apt update
		sudo apt install mysql-server
	
	#Ubuntu/Debian:
	elif command_exists apt-get; then
		sudo apt-get update
		sudo apt-get install mysql-server
	
	#macOS (using Homebrew):
	elif command_exists brew; then
		brew update
		brew install mysql
	#Arch Linux:
	elif command_exists pacman; then
		sudo pacman -Syu
		sudo pacman -S mysql
	
	#CentOS/RHEL:
	elif command_exists yum; then
		sudo yum update
		sudo yum install mysql-server

	#Fedora:
	elif command_exists dnf; then
		sudo dnf install mysql-server
	#FreeBSD:
	elif command_exists pkg; then
		pkg update
		pkg install mysql80-server

	#OpenSUSE:
	elif command_exists zypper; then
		sudo zypper refresh
		sudo zypper install mysql-community-server

	else
		echo "Mysql not found unable to install automatically. Install mysql manually......."
		exit 1
	fi
fi
#Again verifying mysql is present or not .
if ! command_exists mysql; then
	echo "Mysql not found install it first."
	exit 1
else
	#Checking wheather mysql service is running or not if not trying to start it
	attempts=0
	if [ "$(uname -s)"=="Linux" ]; then
		while ! systemctl is-active --quiet mysql; do
			if [ $attempts -gt 5 ]; then
				echo -e "Unable to start the mysql service. No attempts left \n Start it mannually then run this script again....."
				exit 1
			fi
			echo "Trying to start mysql service.........."
			if command_exists mariadb; then
				sudo systemctl start mariadb
				if [ "$?" -ne 0 ]; then
					sudo mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
					sudo chown -R mysql:mysql /var/lib/mysql
					sudo systemctl start mariadb
				fi
			else
				sudo systemctl start mysql
			fi
			attempts=$((attempts+1))
		done
	else
		while ! brew services list | grep -q "mysql.*started"; do
            if [ $attempts -gt 5 ]; then
                echo -e "Unable to start the mysql service. No attempts left \n Start it mannually then run this script again....."
                exit 1
            fi
			echo "Trying to start mysql service.........."
			brew services start mysql
            attempts=$((attempts+1))
		done
	fi
	echo "mysql service is running"
fi

#Again Check if the .env file exists
if [ -f .env ]; then
    # Read the contents of the .env file
    source .env
	output=$(sudo mysql <<EOF
	select Host, user, plugin from mysql.user where user='$MYSQL_USER';
EOF
)
	#checking authenticaion plugin is mysql_native_password or not for existing user if not then modifing it
	if [ -n "$output" ]; then
    	host=$(echo "$output" |awk '{print $1}' | grep -v 'Host')
    	user=$(echo "$output" |awk '{print $2}' | grep -v 'user')
    	plugin=$(echo "$output" |awk '{print $3}' | grep -v 'plugin')
    	if [  "$plugin" == "mysql_native_password" ]; then
        	echo "User $MYSQL_USER present and can be connect with mysql.connector."
    	else
			echo "User present...$MYSQL_USER using $plugin authentication plugin which will be changed ---> mysql_native_password";
        	sudo mysql <<EOF
        	alter  user "$MYSQL_USER"@"$MYSQL_HOST" identified with mysql_native_password by "$MYSQL_PASSWORD";
EOF
    	fi
	else
		#creating user if not exists
    	echo "User Not Exists......"
    	echo "creating User $MYSQL_USER with mysql_native_password plugin for connect through mysql.connector"
        if command_exists mariadb; then
            sudo mysql <<EOF
            create user "$MYSQL_USER"@"$MYSQL_HOST" identified by "$MYSQL_PASSWORD";
EOF
        else
            sudo mysql <<EOF
            create user "$MYSQL_USER"@"$MYSQL_HOST" identified with mysql_native_password by "$MYSQL_PASSWORD";
EOF
        fi
#    	sudo mysql <<EOF
#    	create user "$MYSQL_USER"@"$MYSQL_HOST" identified with mysql_native_password by "$MYSQL_PASSWORD";
#EOF
	fi
    #Creating DB and tables for students
    sudo mysql <<EOF
    SELECT 'Removing students database if already present.' as 'INFO';
    select sleep(5);
	drop database if exists students;
	SELECT 'Now creating fresh students database if not already done before.' as 'INFO';
	create database if not exists students;
	use students;


	create table Attributes_Details(
    	Attribute_Name varchar(100),
    	Data_Type varchar(50));

	create table student(
    	RollNo int primary key,
	    Name varchar(50) not NULL);

	insert into Attributes_Details (Attribute_Name, Data_Type) values
    	('RollNo', 'int'),
	    ('Name', 'varchar');

	grant all privileges on students.* to "$MYSQL_USER"@'localhost';
EOF
else
    echo "Error: .env file not found."
    exit 1
fi
#Renaming setup.sh --> reset.sh
if [ -f "setup.sh" ]; then
	echo "Renaming setup.sh --> reset.sh"
	mv setup.sh reset.sh
else
	if [ -f reset.sh ]; then
		echo "setup.sh already changed to reset.sh"
	else
		echo "setup.sh missing"
	fi
fi
exit 0
