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

@WebServlet("/AssignMentorServlet")
public class AssignMentorServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("userName") == null) {
            response.sendRedirect("login.html");
            return;
        }

        String action = request.getParameter("action");
        String[] studentUids = request.getParameterValues("student_uids");
        
        // Ensure user is an HOD
        boolean isHod = session.getAttribute("isHod") != null ? (Boolean) session.getAttribute("isHod") : false;
        if (!isHod) {
            response.sendRedirect("home.jsp?msg=Error: Unauthorized Access");
            return;
        }

        if (studentUids != null && studentUids.length > 0) {
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
                    
                    if ("assign".equals(action)) {
                        String mentorUid = request.getParameter("mentor_uid");
                        if (mentorUid == null || mentorUid.trim().isEmpty()) {
                            response.sendRedirect("home.jsp?msg=Error: No mentor selected");
                            return;
                        }

                        // 1. Assign the students to the mentor
                        PreparedStatement ps = con.prepareStatement("UPDATE users SET mentor_uid = ? WHERE username = ?");
                        for (String sUid : studentUids) {
                            ps.setString(1, mentorUid);
                            ps.setString(2, sUid);
                            ps.addBatch();
                        }
                        ps.executeBatch();
                        
                        // 2. Automatically upgrade the Faculty to Mentor Role (3)
                        PreparedStatement promote = con.prepareStatement("UPDATE users SET role_id = 3 WHERE username = ? AND role_id = 4");
                        promote.setString(1, mentorUid);
                        promote.executeUpdate();

                        response.sendRedirect("home.jsp?msg=Success: Students assigned and Faculty designated as Mentor");
                        return;

                    } else if ("unassign".equals(action)) {
                        
                        // We need to find out WHO the mentor was before we unassign the students
                        String mentorUid = null;
                        PreparedStatement findMentor = con.prepareStatement("SELECT mentor_uid FROM users WHERE username = ?");
                        findMentor.setString(1, studentUids[0]); 
                        ResultSet rs = findMentor.executeQuery();
                        if (rs.next()) mentorUid = rs.getString("mentor_uid");
                        
                        // 1. Unassign the students
                        PreparedStatement ps = con.prepareStatement("UPDATE users SET mentor_uid = NULL WHERE username = ?");
                        for (String sUid : studentUids) {
                            ps.setString(1, sUid);
                            ps.addBatch();
                        }
                        ps.executeBatch();
                        
                        // 2. Check if this mentor has any students left. If not, demote back to Faculty (4)
                        if (mentorUid != null) {
                            PreparedStatement check = con.prepareStatement("SELECT COUNT(*) AS count FROM users WHERE mentor_uid = ?");
                            check.setString(1, mentorUid);
                            ResultSet rsCount = check.executeQuery();
                            if (rsCount.next() && rsCount.getInt("count") == 0) {
                                PreparedStatement demote = con.prepareStatement("UPDATE users SET role_id = 4 WHERE username = ? AND role_id = 3");
                                demote.setString(1, mentorUid);
                                demote.executeUpdate();
                            }
                        }

                        response.sendRedirect("home.jsp?msg=Success: Students unassigned");
                        return;
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
                response.sendRedirect("home.jsp?msg=Error: Server operation failed");
                return;
            }
        }
        response.sendRedirect("home.jsp?msg=Error: No students selected");
    }
}