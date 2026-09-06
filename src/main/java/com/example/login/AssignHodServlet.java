package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/assignHod")
public class AssignHodServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || (Integer) session.getAttribute("roleId") != 1) {
            response.sendRedirect("login.html");
            return;
        }

        String facultyUid = request.getParameter("faculty_uid").trim();

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
                
                // 1. Verify user is a standard Faculty (role 4) and NOT already an HOD
                PreparedStatement psFind = con.prepareStatement("SELECT department FROM users WHERE username = ? AND role_id = 4 AND is_hod = FALSE");
                psFind.setString(1, facultyUid);
                ResultSet rs = psFind.executeQuery();

                if (rs.next()) {
                    String targetDept = rs.getString("department");

                    // 2. Demote the current HOD and revert them to standard Faculty (role 4)
                    PreparedStatement psDemote = con.prepareStatement("UPDATE users SET is_hod = FALSE, role_id = 4 WHERE department = ? AND is_hod = TRUE");
                    psDemote.setString(1, targetDept);
                    psDemote.executeUpdate();

                    // 3. Promote the new Faculty to HOD
                    PreparedStatement psPromote = con.prepareStatement("UPDATE users SET is_hod = TRUE WHERE username = ?");
                    psPromote.setString(1, facultyUid);
                    psPromote.executeUpdate();

                    response.sendRedirect("home.jsp?msg=Success: " + facultyUid + " is now HOD. Previous HOD reverted to Faculty.");
                } else {
                    response.sendRedirect("home.jsp?msg=Error: User is a Mentor, already an HOD, or invalid.");
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: Server issue occurred.");
        }
    }
}