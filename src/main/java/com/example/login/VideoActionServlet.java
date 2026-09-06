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

@WebServlet("/videoAction")
public class VideoActionServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        String action = request.getParameter("action"); 
        String id = request.getParameter("id"); // Can be video ID or request ID depending on action
        String view = request.getParameter("view"); 

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
                
                if ("approve".equals(action)) {
                    PreparedStatement ps = con.prepareStatement("UPDATE videos SET status='approved' WHERE id=?");
                    ps.setString(1, id);
                    ps.executeUpdate();
                
                } else if ("delete".equals(action)) {
                    PreparedStatement ps = con.prepareStatement("UPDATE videos SET status='deleted' WHERE id=?");
                    ps.setString(1, id);
                    ps.executeUpdate();
                    
                } else if ("deleteRequest".equals(action)) {
                    // 1. Delete the Task Request completely
                    PreparedStatement ps1 = con.prepareStatement("DELETE FROM video_requests WHERE id=?");
                    ps1.setString(1, id);
                    ps1.executeUpdate();
                    
                    // 2. Soft-delete ALL videos that students uploaded for this specific request
                    PreparedStatement ps2 = con.prepareStatement("UPDATE videos SET status='deleted' WHERE request_id=?");
                    ps2.setString(1, id);
                    ps2.executeUpdate();
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        
        if ("approvals".equals(view)) {
            response.sendRedirect("home.jsp?msg=Success: Action Completed&view=approvals");
        } else if ("gallery".equals(view)) {
            response.sendRedirect("VideoGalleryServlet");
        } else {
            String referer = request.getHeader("Referer");
            response.sendRedirect(referer != null ? referer : "home.jsp");
        }
    }
}