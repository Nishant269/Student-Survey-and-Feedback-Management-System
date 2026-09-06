package com.example.login;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import jakarta.servlet.http.Part;

@WebServlet("/UploadVideoServlet")
@MultipartConfig(fileSizeThreshold = 1024 * 1024 * 2, maxFileSize = 1024 * 1024 * 50, maxRequestSize = 1024 * 1024 * 100)
public class UploadVideoServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        String title = request.getParameter("title");
        Part filePart = request.getPart("videoFile");
        
        String requestIdStr = request.getParameter("requestId");
        int requestId = (requestIdStr != null && !requestIdStr.isEmpty()) ? Integer.parseInt(requestIdStr) : 0;

        HttpSession session = request.getSession();
        String userName = (String) session.getAttribute("userName");
        Object roleObj = session.getAttribute("roleId");
        int rId = (roleObj != null) ? (Integer)roleObj : 0;

        String userDept = "General";
        
        // CHANGED: Alumni (5) now require approval just like Students (2)
        String status = (rId == 2 || rId == 5) ? "pending" : "approved"; 

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

            Connection con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);

            PreparedStatement psUser = con.prepareStatement("SELECT department FROM users WHERE username = ?");
            psUser.setString(1, (String) session.getAttribute("uid")); 
            ResultSet rs = psUser.executeQuery();
            if (rs.next()) {
                String d = rs.getString("department");
                if (d != null && !d.isEmpty()) userDept = d;
            }

            String fileName = Paths.get(filePart.getSubmittedFileName()).getFileName().toString();
            String uniqueFileName = System.currentTimeMillis() + "_" + fileName;
            String uploadPath = getServletContext().getRealPath("") + File.separator + "uploaded_videos";
            File uploadDir = new File(uploadPath);
            if (!uploadDir.exists()) uploadDir.mkdir();

            try (InputStream input = filePart.getInputStream()) {
                Files.copy(input, Paths.get(uploadPath + File.separator + uniqueFileName), StandardCopyOption.REPLACE_EXISTING);
            }

            String sql = "INSERT INTO videos (title, filename, department, uploaded_by, status, request_id) VALUES (?, ?, ?, ?, ?, ?)";
            PreparedStatement psVideo = con.prepareStatement(sql);
            psVideo.setString(1, title);
            psVideo.setString(2, uniqueFileName);
            psVideo.setString(3, userDept);
            psVideo.setString(4, userName);
            psVideo.setString(5, status);
            psVideo.setInt(6, requestId); 
            
            psVideo.executeUpdate();
            con.close();
            
            response.sendRedirect("home.jsp");

        } catch (Exception e) {
            e.printStackTrace();
            response.getWriter().println("Error: " + e.getMessage());
        }
    }
}