package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import org.mindrot.jbcrypt.BCrypt;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/login")
public class LoginServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {

        String user = request.getParameter("username"); 
        String pass = request.getParameter("password");

        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            e.printStackTrace();
            response.sendRedirect("error.jsp");
            return;
        }
        
        // --- UPDATED CLOUD-ONLY DATABASE CONNECTION ---
        String dbUrl = System.getenv("DB_URL");
        String dbUser = System.getenv("DB_USER");
        String dbPassword = System.getenv("DB_PASSWORD");
        
        // Strict check to ensure variables are set before attempting to connect
        if (dbUrl == null || dbUser == null || dbPassword == null) {
            System.err.println("CRITICAL ERROR: Cloud Database environment variables are missing!");
            response.sendRedirect("error.jsp");
            return;
        }
        // ----------------------------------------------

        try (Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword)) {
            
            // --- 1. UPDATED SQL QUERY TO INCLUDE is_hod ---
            String sql = "SELECT name, password, role_id, is_hod FROM users WHERE username = ?";
            PreparedStatement ps = con.prepareStatement(sql);
            ps.setString(1, user);
            
            ResultSet rs = ps.executeQuery();

            if (rs.next()) {
                String dbHashedPassword = rs.getString("password"); 
                
                if (BCrypt.checkpw(pass, dbHashedPassword)) {
                    
                    // SUCCESS!
                    String realName = rs.getString("name");
                    int roleId = rs.getInt("role_id");
                    
                    // --- 2. FETCH THE NEW HOD FLAG ---
                    boolean isHod = rs.getBoolean("is_hod");
                    
                    HttpSession session = request.getSession();
                    session.setAttribute("userName", realName); 
                    session.setAttribute("roleId", roleId);
                    session.setAttribute("uid", user); 
                    
                    // --- 3. STORE THE HOD FLAG IN THE SESSION ---
                    session.setAttribute("isHod", isHod); 
                    
                    response.sendRedirect("home.jsp");
                } else {
                    response.sendRedirect("error.jsp");
                }
            } else {
                response.sendRedirect("error.jsp");
            }
        } catch (SQLException e) {
            e.printStackTrace();
            response.sendRedirect("error.jsp");
        }
    }
}