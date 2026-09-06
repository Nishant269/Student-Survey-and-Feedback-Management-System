package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import org.mindrot.jbcrypt.BCrypt;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/addStudent")
public class AddStudentServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        String name = request.getParameter("name").trim();
        String rollNumber = request.getParameter("roll_number").trim();
        String department = request.getParameter("department");
        String year = request.getParameter("year");
        String user = request.getParameter("username");
        String pass = request.getParameter("password");
        
        int roleId = 2; // Default Student
        if(request.getParameter("role_id") != null && !request.getParameter("role_id").isEmpty()) {
             try { roleId = Integer.parseInt(request.getParameter("role_id")); } catch (NumberFormatException e) { roleId = 2; }
        }

        // Clean Data based on Role
        if (roleId == 1) { // Admin
            department = null; year = null;
            if (rollNumber == null || rollNumber.isEmpty()) rollNumber = "ADMIN";
        } else if (roleId == 3 || roleId == 4 || roleId == 5) { // Mentor, Faculty, Alumni
            year = null;
            if (rollNumber == null || rollNumber.isEmpty()) rollNumber = "-"; 
        }

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
            
            // --- UPDATED CLOUD-ONLY DATABASE CONNECTION ---
            String dbUrl = System.getenv("DB_URL");
            String dbUser = System.getenv("DB_USER");
            String dbPassword = System.getenv("DB_PASSWORD");
            
            // Strict check to ensure variables are set before attempting to connect
            if (dbUrl == null || dbUser == null || dbPassword == null) {
                throw new Exception("Cloud Database environment variables are missing!");
            }

            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword)) {

                // --- 1. VERIFICATION & GET EMAIL ---
                String officialEmail = null;
                String verifySql = "";

                if (roleId == 2) { 
                    verifySql = "SELECT email FROM student_details WHERE LOWER(student_name) = LOWER(?) AND roll_number = ? AND department = ? AND year = ?";
                } else if (roleId == 3) { 
                    verifySql = "SELECT email FROM mentor_details WHERE LOWER(name) = LOWER(?) AND unique_id = ? AND department = ?";
                } else if (roleId == 4) { 
                    verifySql = "SELECT email FROM faculty_details WHERE LOWER(name) = LOWER(?) AND unique_id = ? AND department = ?";
                } else if (roleId == 5) { 
                    verifySql = "SELECT email FROM alumni_details WHERE LOWER(name) = LOWER(?) AND roll_number = ? AND department = ?";
                } else if (roleId == 1) { 
                    verifySql = "SELECT email FROM admin_details WHERE LOWER(name) = LOWER(?) AND unique_id = ?"; 
                }

                PreparedStatement psVerify = con.prepareStatement(verifySql);
                psVerify.setString(1, name);
                psVerify.setString(2, rollNumber);
                if (roleId == 2) {
                    psVerify.setString(3, department);
                    psVerify.setString(4, year);
                } else if (roleId == 3 || roleId == 4 || roleId == 5) {
                    psVerify.setString(3, department);
                }
                
                ResultSet rsVerify = psVerify.executeQuery();
                if (rsVerify.next()) {
                    officialEmail = rsVerify.getString("email");
                }

                if (officialEmail == null || officialEmail.isEmpty()) {
                    response.sendRedirect("home.jsp?msg=Error: Details do not match the official records uploaded by Admin.");
                    return; 
                }

                // --- 2. DUPLICATE CHECK ---
                String checkSql = "SELECT id FROM users WHERE roll_number = ? AND role_id = ?";
                PreparedStatement psCheck = con.prepareStatement(checkSql);
                psCheck.setString(1, rollNumber);
                psCheck.setInt(2, roleId);
                if (psCheck.executeQuery().next()) {
                    response.sendRedirect("home.jsp?msg=Error: Account with this Roll/ID already exists.");
                    return;
                }
                
                // --- 3. USERNAME CHECK ---
                String userCheckSql = "SELECT id FROM users WHERE username = ?";
                PreparedStatement psUserCheck = con.prepareStatement(userCheckSql);
                psUserCheck.setString(1, user);
                if (psUserCheck.executeQuery().next()) {
                    response.sendRedirect("home.jsp?msg=Error: Username is already taken.");
                    return;
                }

                // --- 4. INSERT INTO USERS (Admin bypasses OTP) ---
                String hashedPassword = BCrypt.hashpw(pass, BCrypt.gensalt());
                String sql = "INSERT INTO users (name, roll_number, department, year, username, password, role_id, email) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
                PreparedStatement ps = con.prepareStatement(sql);
                ps.setString(1, name);
                ps.setString(2, rollNumber);
                ps.setString(3, department);
                ps.setString(4, year);
                ps.setString(5, user);
                ps.setString(6, hashedPassword);
                ps.setInt(7, roleId);
                ps.setString(8, officialEmail);
                
                ps.executeUpdate();
                
                response.sendRedirect("home.jsp?msg=Success: User account created successfully!");
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: " + e.getMessage());
        }
    }
}