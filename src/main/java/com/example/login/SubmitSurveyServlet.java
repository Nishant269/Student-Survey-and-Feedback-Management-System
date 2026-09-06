package com.example.login;

import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.util.ArrayList;
import java.util.List;
import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

@WebServlet("/submitSurvey")
public class SubmitSurveyServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        HttpSession session = request.getSession(false);
        if (session == null || session.getAttribute("uid") == null) {
            response.setStatus(HttpServletResponse.SC_UNAUTHORIZED);
            return;
        }

        String uid = (String) session.getAttribute("uid");
        String surveyIdStr = request.getParameter("survey_id");

        // 1. DYNAMICALLY CAPTURE ALL ANSWERS
        // The frontend sends inputs named q0, q1, q2, etc. 
        // We will loop through them until we don't find any more.
        List<String> answerList = new ArrayList<>();
        int index = 0;
        while (true) {
            String ans = request.getParameter("q" + index);
            if (ans == null) break; // Break the loop when no more questions exist
            answerList.add(ans);
            index++;
        }

        // 2. FORMAT INTO JSON STRING
        // Convert the list into a string that looks like: "[5, 4, 3]"
        StringBuilder jsonAnswers = new StringBuilder("[");
        for (int i = 0; i < answerList.size(); i++) {
            if (i > 0) jsonAnswers.append(",");
            jsonAnswers.append(answerList.get(i));
        }
        jsonAnswers.append("]");

        try {
            int surveyId = Integer.parseInt(surveyIdStr);
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
                
                // 3. UPDATED SQL: Now we insert into the 'answers' column too
                PreparedStatement ps = con.prepareStatement("INSERT INTO survey_responses (survey_id, user_uid, answers) VALUES (?, ?, ?)");
                ps.setInt(1, surveyId);
                ps.setString(2, uid);
                ps.setString(3, jsonAnswers.toString()); 
                ps.executeUpdate();
                
                // 4. Clear the notification from their dashboard
                PreparedStatement psClick = con.prepareStatement("INSERT IGNORE INTO link_clicks (user_uid, link_id) VALUES (?, ?)");
                psClick.setString(1, uid);
                psClick.setInt(2, surveyId);
                psClick.executeUpdate();
            }
            
            // Send success response if everything worked perfectly
            response.setStatus(HttpServletResponse.SC_OK);
            
        } catch (Exception e) {
            e.printStackTrace();
            // Send error response to the frontend if something crashes
            response.setStatus(HttpServletResponse.SC_INTERNAL_SERVER_ERROR);
        }
    }
}