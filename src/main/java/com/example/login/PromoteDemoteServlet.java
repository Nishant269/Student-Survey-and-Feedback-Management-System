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

@WebServlet("/promoteDemote")
public class PromoteDemoteServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        response.setContentType("application/json");
        response.setCharacterEncoding("UTF-8");
        
        Object roleObj = request.getSession().getAttribute("roleId");
        int rId = (roleObj != null) ? (Integer) roleObj : 0;
        boolean isHod = request.getSession().getAttribute("isHod") != null ? (Boolean) request.getSession().getAttribute("isHod") : false;
        
        if (rId != 1 && !(rId == 4 && isHod)) {
            response.getWriter().write("{\"status\":\"error\", \"message\":\"Unauthorized\"}");
            return;
        }

        String uid = request.getParameter("uid");
        String action = request.getParameter("action"); 
        
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
            
            PreparedStatement ps = con.prepareStatement("SELECT role_id, year FROM users WHERE username = ?");
            ps.setString(1, uid);
            ResultSet rs = ps.executeQuery();
            
            if (rs.next()) {
                int role = rs.getInt("role_id");
                String year = rs.getString("year");
                
                if (role == 5) { year = "Alumni"; }
                
                if ("promote".equals(action)) {
                    if ("1st".equals(year)) { year = "2nd"; }
                    else if ("2nd".equals(year)) { year = "3rd"; }
                    else if ("3rd".equals(year)) { year = "4th"; }
                    else if ("4th".equals(year)) { year = "Alumni"; role = 5; } 
                } 
                else if ("demote".equals(action)) {
                    if ("Alumni".equals(year) || role == 5) { year = "4th"; role = 2; } 
                    else if ("4th".equals(year)) { year = "3rd"; }
                    else if ("3rd".equals(year)) { year = "2nd"; }
                    else if ("2nd".equals(year)) { year = "1st"; }
                }
                
                PreparedStatement update = con.prepareStatement("UPDATE users SET year = ?, role_id = ? WHERE username = ?");
                update.setString(1, year);
                update.setInt(2, role);
                update.setString(3, uid);
                update.executeUpdate();
            }
            con.close();
            
            // Return success JSON
            response.getWriter().write("{\"status\":\"success\"}");
        } catch (Exception e) {
            e.printStackTrace();
            response.getWriter().write("{\"status\":\"error\"}");
        }
    }
}