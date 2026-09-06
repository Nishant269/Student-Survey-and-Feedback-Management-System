package com.example.login;

import java.io.IOException;
import java.io.PrintWriter;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.mindrot.jbcrypt.BCrypt;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@WebServlet("/AdminUserAction")
public class AdminUserActionServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
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

            if ("search".equals(action)) {
                String query = request.getParameter("searchQuery");
                List<Map<String,String>> searchResults = new ArrayList<>();
                String sql = "SELECT name, username, department, role_id FROM users WHERE name LIKE ? OR username LIKE ?";
                PreparedStatement ps = con.prepareStatement(sql);
                ps.setString(1, "%" + query + "%");
                ps.setString(2, "%" + query + "%");
                ResultSet rs = ps.executeQuery();
                while(rs.next()) {
                    Map<String,String> u = new HashMap<>();
                    u.put("name", rs.getString("name"));
                    u.put("uid", rs.getString("username"));
                    u.put("dept", rs.getString("department"));
                    u.put("role", String.valueOf(rs.getInt("role_id")));
                    searchResults.add(u);
                }
                request.setAttribute("searchResults", searchResults);
                request.getRequestDispatcher("home.jsp").forward(request, response);

            } else if ("suggest".equals(action)) {
                String query = request.getParameter("q");
                response.setContentType("text/html");
                PrintWriter out = response.getWriter();
                if(query != null && query.length() >= 2) {
                    String sql = "SELECT name, username FROM users WHERE name LIKE ? OR username LIKE ? LIMIT 5";
                    PreparedStatement ps = con.prepareStatement(sql);
                    ps.setString(1, "%" + query + "%");
                    ps.setString(2, "%" + query + "%");
                    ResultSet rs = ps.executeQuery();
                    while(rs.next()) {
                        String n = rs.getString("name");
                        String u = rs.getString("username");
                        out.println("<div class='p-2 hover:bg-gray-100 cursor-pointer border-b' onclick=\"selectUser('"+u+"')\">"+n+" ("+u+")</div>");
                    }
                }
            } else if ("resetPass".equals(action)) {
                String targetUser = request.getParameter("targetUser");
                String newPass = request.getParameter("newPass");
                String confirmPass = request.getParameter("confirmPass");
                
                // VALIDATION: Check match
                if (!newPass.equals(confirmPass)) {
                    // ERROR: Pass 'modal' and 'targetUser' back to JSP
                    response.sendRedirect("home.jsp?msg=Error: Passwords do not match&modal=adminReset&targetUser=" + targetUser); 
                    return;
                }

                String hashedPassword = BCrypt.hashpw(newPass, BCrypt.gensalt());
                PreparedStatement ps = con.prepareStatement("UPDATE users SET password = ? WHERE username = ?");
                ps.setString(1, hashedPassword);
                ps.setString(2, targetUser);
                ps.executeUpdate();
                
                response.sendRedirect("home.jsp?msg=Success: Password reset successfully");
            }
            con.close();
        } catch (Exception e) {
            e.printStackTrace();
            if(!"suggest".equals(action)) response.sendRedirect("home.jsp?msg=Error: System error");
        }
    }
}