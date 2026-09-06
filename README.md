# Student Survey & Feedback Management System

A role-based Java web application designed to manage student feedback, surveys, and video assignments. The system features distinct dashboards and permissions for Students, Faculty, Mentors, Heads of Department (HODs), and Administrators.

## 🚀 Features
* **Role-Based Access Control:** Secure logins tailored for Admin, HOD, Faculty, Mentor, Student, and Alumni.
* **Survey Management:** Push customized surveys to specific departments or years, and view real-time analytics and score breakdowns.
* **Video Assignments:** Request, upload, and review video submissions with approval workflows.
* **Bulk Data Upload:** Admins can bulk-import user data (Students, Faculty, etc.) via `.xlsx` Excel files.
* **Cloud Ready:** Fully configured for deployment via Docker and Render, utilizing secure environment variables for cloud database connections.

---

## 🛠️ Prerequisites

To run this project locally, you will need:
* **Java Development Kit (JDK) 17**
* **Apache Tomcat 10.x**
* **MySQL** (Local server or Cloud database like Aiven)
* **Eclipse IDE for Enterprise Java** (or IntelliJ IDEA)
* **Maven** (for dependency management)

---

## 🔐 Environment Variables Configuration

For security, this application does not hardcode database credentials. You **must** set up the following environment variables before running the application locally or in the cloud.

### Required Variables
| Variable Name | Description | Example Value |
| :--- | :--- | :--- |
| `DB_URL` | The JDBC connection string to your MySQL database. | `jdbc:mysql://localhost:3306/my_login_app?ssl-mode=REQUIRED` (Local) <br> *or* <br> `jdbc:mysql://avnadmin:xyz@your-aiven-host:27506/my_login_app?ssl-mode=REQUIRED` (Cloud) |
| `DB_USER` | Your MySQL username. | `root` or `avnadmin` |
| `DB_PASSWORD` | Your MySQL password. | `your_secure_password` |

### How to set them locally (Windows & Eclipse)

**Method 1: Windows System Variables (Global)**
1. Press the Windows key, type **Environment Variables**, and select **Edit the system environment variables**.
2. Click the **Environment Variables...** button at the bottom.
3. Under **System variables**, click **New...**.
4. Add the `Variable name` (e.g., `DB_URL`) and `Variable value`. Repeat for all three variables.
5. Click **OK** to save. 
6. **CRITICAL:** You must completely restart Eclipse and your command prompt for Windows to pass these new variables to your apps.

**Method 2: Eclipse Tomcat Configuration (Recommended)**
If Eclipse is failing to read your Windows system variables, you can inject them directly into Tomcat:
1. In Eclipse, go to the **Servers** tab.
2. Double-click your **Tomcat v10.0 Server**.
3. Click the **Open launch configuration** link.
4. Navigate to the **Environment** tab.
5. Click **Add...** and input your `DB_URL`, `DB_USER`, and `DB_PASSWORD` key-value pairs here.
6. Click **Apply and Close**.

---

## 💻 Local Setup & Running the Project

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/your-username/your-repo-name.git](https://github.com/your-username/your-repo-name.git)
   cd your-repo-name
