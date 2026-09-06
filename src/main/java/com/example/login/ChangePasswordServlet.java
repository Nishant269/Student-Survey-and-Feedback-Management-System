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
import jakarta.servlet.http.HttpSession;

@WebServlet("/ChangePasswordServlet")
public class ChangePasswordServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession();
        String uid = (String) session.getAttribute("uid");
        
        String currentPass = request.getParameter("currentPass");
        String newPass = request.getParameter("newPass");
        String confirmPass = request.getParameter("confirmPass");

        // 1. Check Match -> On Error, keep modal open
        if (!newPass.equals(confirmPass)) {
            response.sendRedirect("home.jsp?msg=Error: New passwords do not match&modal=changePass");
            return;
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
            
            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
            // ----------------------------------------------
            
            PreparedStatement psCheck = con.prepareStatement("SELECT password FROM users WHERE username = ?");
            psCheck.setString(1, uid);
            ResultSet rs = psCheck.executeQuery();
            
            if (rs.next()) {
                String dbHash = rs.getString("password");
                if (BCrypt.checkpw(currentPass, dbHash)) {
                    // Success
                    String newHash = BCrypt.hashpw(newPass, BCrypt.gensalt());
                    PreparedStatement psUpdate = con.prepareStatement("UPDATE users SET password = ? WHERE username = ?");
                    psUpdate.setString(1, newHash);
                    psUpdate.setString(2, uid);
                    psUpdate.executeUpdate();
                    
                    response.sendRedirect("home.jsp?msg=Success: Password changed successfully");
                } else {
                    // 2. Wrong Old Password -> On Error, keep modal open
                    response.sendRedirect("home.jsp?msg=Error: Incorrect current password&modal=changePass");
                }
            }
            con.close();
        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: Server error occurred");
        }
    }
}