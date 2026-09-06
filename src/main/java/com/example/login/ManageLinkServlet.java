package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/ManageLinkServlet")
public class ManageLinkServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String action = request.getParameter("action");
        String id = request.getParameter("id");

        if ("delete".equals(action) && id != null) {
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
                
                String sql = "DELETE FROM feedback_links WHERE id = ?";
                PreparedStatement ps = con.prepareStatement(sql);
                ps.setString(1, id);
                ps.executeUpdate();
                
                con.close();
                response.sendRedirect("home.jsp?msg=Success: Link deleted successfully");
                
            } catch (Exception e) {
                e.printStackTrace();
                response.sendRedirect("home.jsp?msg=Error: Server error occurred");
            }
        } else {
            // Fallback if the action wasn't recognized or ID was missing
            response.sendRedirect("home.jsp"); 
        }
    }
}