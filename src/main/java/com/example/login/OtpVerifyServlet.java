package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.util.Map;

import org.mindrot.jbcrypt.BCrypt;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/verifyOtp")
public class OtpVerifyServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        
        String sessionOtp = (String) session.getAttribute("registrationOtp");
        Map<String, Object> userData = (Map<String, Object>) session.getAttribute("tempUserData");
        String userOtp = request.getParameter("userOtp").trim();

        // 1. Session Expired Check
        if (sessionOtp == null || userData == null) {
            response.getWriter().println("<h1>Session Expired</h1><a href='register.html'>Register Again</a>");
            return;
        }

        // 2. Validate OTP
        if (!sessionOtp.equals(userOtp)) {
            response.sendRedirect("otp_verify.jsp?email=your_email&error=true");
            return;
        }

        // 3. OTP is correct! Insert into Database
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
            // ----------------------------------------------
            
            try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword)) {
                
                String pass = (String) userData.get("pass");
                String hashedPassword = BCrypt.hashpw(pass, BCrypt.gensalt());
                
                String sql = "INSERT INTO users (name, roll_number, department, year, username, password, role_id, email) VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
                PreparedStatement ps = con.prepareStatement(sql);
                ps.setString(1, (String) userData.get("name"));
                ps.setString(2, (String) userData.get("roll"));
                ps.setString(3, (String) userData.get("dept"));
                ps.setString(4, (String) userData.get("year"));
                ps.setString(5, (String) userData.get("user"));
                ps.setString(6, hashedPassword);
                ps.setInt(7, (Integer) userData.get("role"));
                ps.setString(8, (String) userData.get("email"));
                
                ps.executeUpdate();
                
                // Clear session data to prevent duplicate submissions
                session.removeAttribute("registrationOtp");
                session.removeAttribute("tempUserData");

                response.sendRedirect("login.html?msg=Registration Successful");
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.getWriter().println("Error saving user: " + e.getMessage());
        }
    }
}