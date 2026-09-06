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
import jakarta.servlet.http.HttpSession;

@WebServlet("/trackLinkClick")
public class TrackLinkClickServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("uid") == null) {
            return; // Ignore if not logged in
        }

        String uid = (String) session.getAttribute("uid");
        String linkIdStr = request.getParameter("id");

        if (linkIdStr != null && !linkIdStr.isEmpty()) {
            try {
                int linkId = Integer.parseInt(linkIdStr);
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
                    String sql = "INSERT INTO link_clicks (user_uid, link_id) SELECT ?, ? WHERE NOT EXISTS (SELECT 1 FROM link_clicks WHERE user_uid = ? AND link_id = ?)";
                    PreparedStatement ps = con.prepareStatement(sql);
                    ps.setString(1, uid);
                    ps.setInt(2, linkId);
                    ps.setString(3, uid);
                    ps.setInt(4, linkId);
                    ps.executeUpdate();
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
        
        // Return a silent 200 OK status to the browser's AJAX request
        response.setStatus(HttpServletResponse.SC_OK); 
    }
}