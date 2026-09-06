<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.sql.*" %>
<%@ page import="java.text.SimpleDateFormat" %>
<%@ page import="java.util.*" %>

<%
    // 1. SECURITY HEADERS
    response.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    response.setHeader("Pragma", "no-cache");
    response.setDateHeader("Expires", 0);

    // 2. SESSION CHECK
    if (session.getAttribute("userName") == null) {
        response.sendRedirect("login.html");
        return;
    }
    
    String userName = (String) session.getAttribute("userName");
    String sessionUid = (String) session.getAttribute("uid");
    Object roleObj = session.getAttribute("roleId");
    int rId = (roleObj != null) ? (Integer)roleObj : 0;
    
    // FETCH HOD FLAG
    boolean isHod = session.getAttribute("isHod") != null ? (Boolean)session.getAttribute("isHod") : false;
    
    // 3. GLOBAL VARIABLES
    String myUid = (sessionUid != null) ? sessionUid : "";
    String myDept = "-";
    String myYear = "-";
    String myRoll = "-";
    String myMentorName = "Not Assigned";
    
    SimpleDateFormat sdf = new SimpleDateFormat("MMM d, h:mm a"); 

    // URL Params
    String urlMsg = request.getParameter("msg");
    String openModalType = request.getParameter("modal");
    String targetUserForReset = request.getParameter("targetUser");
    String viewParam = request.getParameter("view");

    Connection con = null;
    StringBuilder studentJson = new StringBuilder("[");
    
    // Data Containers
    List<Map<String,String>> pendingVideos = new ArrayList<>();
    List<Map<String,String>> myUploads = new ArrayList<>(); 
    Set<Integer> completedTasks = new HashSet<>(); 
    Set<Integer> clickedLinks = new HashSet<>();
    
    List<Map<String,String>> dashboardSurveys = new ArrayList<>();
    List<Map<String,String>> dashboardTasks = new ArrayList<>();
    
    Map<String, List<Map<String,String>>> groupedPushHistory = new LinkedHashMap<>();
    Map<String, List<Map<String,String>>> groupedTaskHistory = new LinkedHashMap<>(); 
    
    List<Map<String,String>> availableMentors = new ArrayList<>();
    List<Map<String,String>> unassignedStudents = new ArrayList<>();
    Map<String, List<Map<String,String>>> assignedMap = new HashMap<>(); 
    List<Map<String,String>> allFacultyList = new ArrayList<>();
    
    // Map for the Students Management List
    Map<String, Map<String, List<Map<String,String>>>> allStudentsMap = new HashMap<>();
    String[] ALL_DEPTS_LIST = {"CSE", "IT", "CIVIL", "MECHANICAL", "ELECTRICAL", "ECE", "CYBER SECURITY", "General"};
    String[] YEAR_ORDER = {"1st", "2nd", "3rd", "4th", "Alumni"};
    for(String d : ALL_DEPTS_LIST) {
        Map<String, List<Map<String,String>>> yMap = new LinkedHashMap<>();
        for(String y : YEAR_ORDER) { yMap.put(y, new ArrayList<>()); }
        allStudentsMap.put(d, yMap);
    }
    
    Set<String> mentorDepts = new HashSet<>();
    Set<String> mentorYears = new HashSet<>();
    
    List<Map<String,String>> searchResults = (List<Map<String,String>>) request.getAttribute("searchResults");
    int nextSurveyId = 1; 
    
    try {
    	Class.forName("com.mysql.cj.jdbc.Driver");

    	String dbUrl = System.getenv("DB_URL");
    	String dbUser = System.getenv("DB_USER");
    	String dbPassword = System.getenv("DB_PASSWORD");

    	if (dbUrl == null || dbUser == null || dbPassword == null) {
    	    throw new Exception("Cloud Database environment variables are missing!");
    	}

    	con = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
        
        try {
            Statement s = con.createStatement();
            ResultSet rsId = s.executeQuery("SELECT MAX(id) FROM feedback_links");
            if (rsId.next()) nextSurveyId = rsId.getInt(1) + 1;
        } catch(Exception ignored){}
        
        PreparedStatement psUser = con.prepareStatement("SELECT department, year, roll_number, mentor_uid FROM users WHERE username = ?");
        psUser.setString(1, sessionUid);
        ResultSet rsUser = psUser.executeQuery();
        if(rsUser.next()){
            myDept = rsUser.getString("department");
            myYear = rsUser.getString("year");
            myRoll = rsUser.getString("roll_number");
            String mUid = rsUser.getString("mentor_uid");
            if(myDept == null) myDept = "";
            if(myYear == null) myYear = "";
            if(myRoll == null) myRoll = "";
            if(mUid != null && !mUid.isEmpty()) {
                PreparedStatement psMenName = con.prepareStatement("SELECT name FROM users WHERE username = ?");
                psMenName.setString(1, mUid);
                ResultSet rsMenName = psMenName.executeQuery();
                if(rsMenName.next()) myMentorName = rsMenName.getString("name");
            }
        }

        try {
            PreparedStatement psClicks = con.prepareStatement("SELECT link_id FROM link_clicks WHERE user_uid = ?");
            psClicks.setString(1, sessionUid);
            ResultSet rsClicks = psClicks.executeQuery();
            while(rsClicks.next()) clickedLinks.add(rsClicks.getInt("link_id"));
        } catch(Exception e) {}

        String sqlMyUploads = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.uploaded_by = ? ORDER BY v.id DESC";
        PreparedStatement psMy = con.prepareStatement(sqlMyUploads);
        psMy.setString(1, userName);
        ResultSet rsMy = psMy.executeQuery();
        while(rsMy.next()){
            Map<String,String> v = new HashMap<>();
            v.put("title", rsMy.getString("title"));
            v.put("filename", rsMy.getString("filename"));
            v.put("status", rsMy.getString("status")); 
            v.put("date", rsMy.getString("uploaded_at"));
            String reqBy = rsMy.getString("requester");
            v.put("requested_by", (reqBy != null) ? reqBy : "Self (Generic)");
            myUploads.add(v);
            int reqId = rsMy.getInt("request_id");
            if(reqId > 0) completedTasks.add(reqId);
        }

        Statement stmtDashS = con.createStatement();
        ResultSet rsDashS = stmtDashS.executeQuery("SELECT * FROM feedback_links ORDER BY id DESC LIMIT 20");
        while(rsDashS.next()) {
            int linkId = rsDashS.getInt("id");
            if(clickedLinks.contains(linkId)) continue;
            
            String tDepts = rsDashS.getString("target_dept");
            String tYears = rsDashS.getString("target_year");
            String tUsers = rsDashS.getString("target_user");
            String postedBy = rsDashS.getString("posted_by");
            
            String questions = "[]";
            try { questions = rsDashS.getString("questions"); if (questions == null) questions = "[]"; } catch (Exception ignored) {} 
            
            boolean show = false;
            if (rId == 2 || rId == 5) { 
                boolean deptMatch = tDepts.equals("All") || tDepts.contains(myDept);
                boolean yearMatch = false;
                if (rId == 5) { yearMatch = tYears.contains("Alumni"); } 
                else { yearMatch = tYears.equals("All") || tYears.contains(myYear); }
                boolean userMatch = tUsers != null && tUsers.contains(myUid);
                if ((deptMatch && yearMatch) || userMatch) show = true;
            }
            if(show) {
                Map<String,String> m = new HashMap<>();
                m.put("id", String.valueOf(linkId));
                m.put("desc", rsDashS.getString("description"));
                m.put("by", postedBy);
                m.put("time", sdf.format(rsDashS.getTimestamp("created_at")));
                m.put("questions", questions.replace("\"", "&quot;")); 
                dashboardSurveys.add(m);
                if(dashboardSurveys.size() >= 5) break; 
            }
        }

        try {
            Statement stmtDashT = con.createStatement();
            ResultSet rsDashT = stmtDashT.executeQuery("SELECT * FROM video_requests ORDER BY id DESC LIMIT 20");
            while(rsDashT.next()) {
                int taskId = rsDashT.getInt("id");
                if(completedTasks.contains(taskId)) continue;
                String tDepts = rsDashT.getString("target_dept");
                String tYears = rsDashT.getString("target_year");
                String tUsers = rsDashT.getString("target_user");
                String postedBy = rsDashT.getString("posted_by");
                
                boolean show = false;
                if (rId == 2 || rId == 5) { 
                    boolean deptMatch = tDepts.equals("All") || tDepts.contains(myDept);
                    boolean yearMatch = false;
                    if (rId == 5) { yearMatch = tYears.contains("Alumni"); } 
                    else { yearMatch = tYears.equals("All") || tYears.contains(myYear); }
                    boolean userMatch = tUsers != null && tUsers.contains(myUid);
                    if ((deptMatch && yearMatch) || userMatch) show = true;
                }
                
                if(show) {
                    Map<String,String> m = new HashMap<>();
                    m.put("desc", rsDashT.getString("description"));
                    m.put("by", postedBy);
                    m.put("time", sdf.format(rsDashT.getTimestamp("created_at")));
                    dashboardTasks.add(m);
                    if(dashboardTasks.size() >= 5) break; 
                }
            }
        } catch(Exception ignored) {}

        if (rId == 1 || rId == 3 || rId == 4) {
            String sqlPending = "SELECT v.*, r.posted_by AS requester FROM videos v LEFT JOIN video_requests r ON v.request_id = r.id WHERE v.status = 'pending'";
            Statement stmtP = con.createStatement();
            ResultSet rsP = stmtP.executeQuery(sqlPending);
            while(rsP.next()){
                String requester = rsP.getString("requester");
                boolean show = false;
                if (requester != null && requester.equals(userName)) show = true;
                else if (requester == null && rId == 1) show = true;
                if (show) {
                    Map<String,String> v = new HashMap<>();
                    v.put("id", String.valueOf(rsP.getInt("id")));
                    v.put("title", rsP.getString("title"));
                    v.put("filename", rsP.getString("filename"));
                    v.put("by", rsP.getString("uploaded_by"));
                    v.put("dept", rsP.getString("department"));
                    pendingVideos.add(v);
                }
            }
        }

        // FETCH STUDENTS
        if (rId == 1 || rId == 3 || rId == 4) {
            String sql = "";
            PreparedStatement psStuds;
            if (rId == 1 || (rId == 4 && isHod)) { 
                sql = "SELECT name, username, department, year, role_id, roll_number FROM users WHERE role_id IN (2, 5) ORDER BY roll_number ASC";
                psStuds = con.prepareStatement(sql);
            } else if (rId == 4) { 
                sql = "SELECT name, username, department, year, role_id, roll_number FROM users WHERE role_id IN (2, 5) AND department = ? ORDER BY roll_number ASC";
                psStuds = con.prepareStatement(sql);
                psStuds.setString(1, myDept);
            } else { 
                sql = "SELECT name, username, department, year, role_id, roll_number FROM users WHERE role_id IN (2, 5) AND mentor_uid = ? ORDER BY roll_number ASC";
                psStuds = con.prepareStatement(sql);
                psStuds.setString(1, userName); 
            }

            ResultSet rsAll = psStuds.executeQuery();
            boolean first = true;
            while(rsAll.next()) {
                String sName = rsAll.getString("name");
                String sUid = rsAll.getString("username");
                String sDept = rsAll.getString("department");
                String sYear = rsAll.getString("year");
                int sRole = rsAll.getInt("role_id");
                
                String sRoll = rsAll.getString("roll_number");
                if (sRoll == null || sRoll.trim().isEmpty()) sRoll = "-";
                
                if(sRole == 5) sYear = "Alumni"; 
                if(sDept == null || sDept.isEmpty()) sDept = "General";
                
                if(allStudentsMap.containsKey(sDept) && allStudentsMap.get(sDept).containsKey(sYear)) {
                    Map<String,String> studentData = new HashMap<>();
                    studentData.put("name", sName);
                    studentData.put("uid", sUid);
                    studentData.put("year", sYear);
                    studentData.put("role", String.valueOf(sRole));
                    studentData.put("roll", sRoll);
                    allStudentsMap.get(sDept).get(sYear).add(studentData);
                }
                
                boolean addToJson = true;
                if(rId == 4 && isHod && !sDept.equals(myDept)) addToJson = false;
                
                if (addToJson) {
                    if(rId == 3) { 
                        if(sDept != null && !sDept.isEmpty()) mentorDepts.add(sDept);
                        if(sYear != null && !sYear.isEmpty()) mentorYears.add(sYear);
                    }
                    if(!first) studentJson.append(",");
                    studentJson.append(String.format("{\"name\":\"%s\", \"uid\":\"%s\", \"dept\":\"%s\", \"year\":\"%s\"}", 
                        sName.replace("'", "\\'"), sUid, sDept, sYear));
                    first = false;
                }
            }
        }

        if (rId == 4 && isHod) { 
            PreparedStatement psMentors = con.prepareStatement("SELECT name, username FROM users WHERE role_id IN (3, 4) AND department = ? AND is_hod = FALSE ORDER BY name");
            psMentors.setString(1, myDept);
            ResultSet rsMentors = psMentors.executeQuery();
            while(rsMentors.next()){
                Map<String,String> m = new HashMap<>();
                m.put("name", rsMentors.getString("name"));
                m.put("uid", rsMentors.getString("username"));
                availableMentors.add(m);
            }
            try {
                PreparedStatement psUn = con.prepareStatement("SELECT name, username, year FROM users WHERE role_id = 2 AND department = ? AND mentor_uid IS NULL ORDER BY year, name");
                psUn.setString(1, myDept);
                ResultSet rsUn = psUn.executeQuery();
                while(rsUn.next()){
                    Map<String,String> s = new HashMap<>();
                    s.put("name", rsUn.getString("name"));
                    s.put("uid", rsUn.getString("username"));
                    s.put("year", rsUn.getString("year"));
                    unassignedStudents.add(s);
                }
                String sqlAssigned = "SELECT s.name AS s_name, s.username AS s_uid, m.name AS m_name, m.username AS m_uid FROM users s JOIN users m ON s.mentor_uid = m.username WHERE s.role_id = 2 AND s.department = ? ORDER BY m.name";
                PreparedStatement psAssigned = con.prepareStatement(sqlAssigned);
                psAssigned.setString(1, myDept);
                ResultSet rsAssigned = psAssigned.executeQuery();
                while(rsAssigned.next()){
                    String mName = rsAssigned.getString("m_name") + " (" + rsAssigned.getString("m_uid") + ")";
                    Map<String,String> s = new HashMap<>();
                    s.put("name", rsAssigned.getString("s_name"));
                    s.put("uid", rsAssigned.getString("s_uid"));
                    if(!assignedMap.containsKey(mName)) assignedMap.put(mName, new ArrayList<>());
                    assignedMap.get(mName).add(s);
                }
            } catch (Exception ignored) {}
        }
        
        if (rId == 1) {
            Statement stmtFac = con.createStatement();
            ResultSet rsFac = stmtFac.executeQuery("SELECT name, username, department FROM users WHERE role_id = 4 AND is_hod = FALSE");
            while(rsFac.next()) {
                Map<String,String> f = new HashMap<>();
                f.put("name", rsFac.getString("name"));
                f.put("uid", rsFac.getString("username"));
                f.put("dept", rsFac.getString("department"));
                allFacultyList.add(f);
            }
        }
        
        // PUSH HISTORY
        if (rId == 1 || rId == 3 || rId == 4) {
            String sqlHist;
            PreparedStatement psHist;
            
            String subQs = ", (SELECT role_id FROM users WHERE username = f.posted_by OR name = f.posted_by LIMIT 1) AS p_role" +
                           ", (SELECT is_hod FROM users WHERE username = f.posted_by OR name = f.posted_by LIMIT 1) AS p_hod ";

            if (rId == 1) {
                sqlHist = "SELECT f.*" + subQs + "FROM feedback_links f ORDER BY f.posted_by, f.created_at DESC";
                psHist = con.prepareStatement(sqlHist);
            } else if (rId == 4 && isHod) {
                sqlHist = "SELECT f.*" + subQs + "FROM feedback_links f WHERE f.posted_by IN (SELECT username FROM users WHERE department = ?) OR f.posted_by IN (SELECT name FROM users WHERE department = ?) ORDER BY f.posted_by, f.created_at DESC";
                psHist = con.prepareStatement(sqlHist);
                psHist.setString(1, myDept);
                psHist.setString(2, myDept);
            } else {
                sqlHist = "SELECT f.*" + subQs + "FROM feedback_links f WHERE f.posted_by = ? ORDER BY f.created_at DESC";
                psHist = con.prepareStatement(sqlHist);
                psHist.setString(1, userName);
            }

            ResultSet rsHist = psHist.executeQuery();
            while(rsHist.next()){
                Map<String,String> h = new HashMap<>();
                int lId = rsHist.getInt("id");
                h.put("id", String.valueOf(lId));
                h.put("desc", rsHist.getString("description"));
                h.put("date", sdf.format(rsHist.getTimestamp("created_at")));
                
                String qStr = rsHist.getString("questions");
                h.put("questions", (qStr != null ? qStr : "[]").replace("\"", "&quot;"));
                
                String poster = rsHist.getString("posted_by");
                int pRole = rsHist.getInt("p_role");
                boolean pHod = rsHist.getBoolean("p_hod");
                String roleStr = "Faculty"; 
                if (pRole == 1) roleStr = "Administrator";
                else if (pRole == 3) roleStr = "Mentor";
                else if (pRole == 4 && pHod) roleStr = "HOD";
                
                String groupKey = roleStr + ": " + poster;
                
                String tDepts = rsHist.getString("target_dept");
                String tYears = rsHist.getString("target_year");
                String tUsers = rsHist.getString("target_user");
                if (tUsers != null && !tUsers.equals("All") && !tUsers.equals("NONE")) {
                    h.put("audience", "Specific Users: " + tUsers);
                } else {
                    h.put("audience", "Dept(s): " + tDepts + " | Year(s): " + tYears);
                }
                
                StringBuilder allAnswers = new StringBuilder("[");
                int respCount = 0;
                try {
                    PreparedStatement psCount = con.prepareStatement("SELECT answers FROM survey_responses WHERE survey_id = ?");
                    psCount.setInt(1, lId);
                    ResultSet rsCount = psCount.executeQuery();
                    while(rsCount.next()) {
                        if (respCount > 0) allAnswers.append(",");
                        String ans = rsCount.getString("answers");
                        allAnswers.append((ans != null && !ans.isEmpty()) ? ans : "[]");
                        respCount++;
                    }
                } catch(Exception e) { }
                allAnswers.append("]");
                
                h.put("response_count", String.valueOf(respCount));
                h.put("all_answers", allAnswers.toString().replace("\"", "&quot;"));
                
                if(!groupedPushHistory.containsKey(groupKey)) {
                    groupedPushHistory.put(groupKey, new ArrayList<>());
                }
                groupedPushHistory.get(groupKey).add(h);
            }
        }
        
        // TASK HISTORY
        if (rId == 1 || rId == 3 || rId == 4) {
            String histSql;
            PreparedStatement psHist;
            
            String subQsT = ", (SELECT role_id FROM users WHERE username = r.posted_by OR name = r.posted_by LIMIT 1) AS p_role" +
                            ", (SELECT is_hod FROM users WHERE username = r.posted_by OR name = r.posted_by LIMIT 1) AS p_hod ";
            
            if (rId == 1) {
                histSql = "SELECT r.*" + subQsT + "FROM video_requests r ORDER BY r.posted_by, r.created_at DESC";
                psHist = con.prepareStatement(histSql);
            } else if (rId == 4 && isHod) {
                histSql = "SELECT r.*" + subQsT + "FROM video_requests r WHERE r.posted_by IN (SELECT username FROM users WHERE department = ?) OR r.posted_by IN (SELECT name FROM users WHERE department = ?) ORDER BY r.posted_by, r.created_at DESC";
                psHist = con.prepareStatement(histSql);
                psHist.setString(1, myDept);
                psHist.setString(2, myDept);
            } else {
                histSql = "SELECT r.*" + subQsT + "FROM video_requests r WHERE r.posted_by = ? ORDER BY r.created_at DESC";
                psHist = con.prepareStatement(histSql);
                psHist.setString(1, userName);
            }
            
            ResultSet rsHist = psHist.executeQuery();
            while(rsHist.next()) {
                Map<String,String> m = new HashMap<>();
                m.put("id", String.valueOf(rsHist.getInt("id")));
                m.put("desc", rsHist.getString("description"));
                
                String poster = rsHist.getString("posted_by");
                int pRole = rsHist.getInt("p_role");
                boolean pHod = rsHist.getBoolean("p_hod");
                String roleStr = "Faculty"; 
                if (pRole == 1) roleStr = "Administrator";
                else if (pRole == 3) roleStr = "Mentor";
                else if (pRole == 4 && pHod) roleStr = "HOD";
                
                String groupKey = roleStr + ": " + poster;
                
                String tDepts = rsHist.getString("target_dept");
                String tYears = rsHist.getString("target_year");
                String tUsers = rsHist.getString("target_user");
                if (tUsers != null && !tUsers.equals("All") && !tUsers.equals("NONE")) {
                    m.put("audience", "Specific Users: " + tUsers);
                } else {
                    m.put("audience", "Dept(s): " + tDepts + " | Year(s): " + tYears);
                }
                
                Timestamp exp = rsHist.getTimestamp("expiry_date");
                boolean active = true;
                if(exp != null) {
                    active = exp.after(new java.util.Date()); 
                    m.put("expiry", sdf.format(exp));
                } else {
                    m.put("expiry", "No Expiry Limit");
                }
                m.put("status", active ? "Active" : "Expired");
                
                if(!groupedTaskHistory.containsKey(groupKey)) {
                    groupedTaskHistory.put(groupKey, new ArrayList<>());
                }
                groupedTaskHistory.get(groupKey).add(m);
            }
        }

    } catch(Exception e) { e.printStackTrace(); }
    studentJson.append("]");

    boolean isRestricted = (rId == 4 || rId == 3);
    String[] visibleDepts = ALL_DEPTS_LIST;
    String[] visibleYears = YEAR_ORDER;
    
    if (rId == 4) {
        visibleDepts = new String[]{myDept}; 
        visibleYears = YEAR_ORDER; 
    } else if (rId == 3) {
        visibleDepts = mentorDepts.toArray(new String[0]);
        visibleYears = mentorYears.toArray(new String[0]);
        if(visibleDepts.length == 0) visibleDepts = new String[]{"No Students Assigned"};
        if(visibleYears.length == 0) visibleYears = new String[]{"-"};
    }
    
    String initialSection = "section-dashboard";
    if (searchResults != null && !searchResults.isEmpty()) {
        initialSection = "section-password-reset";
    } else if ("adminReset".equals(openModalType)) {
        initialSection = "section-password-reset";
    } else if ("approvals".equals(viewParam) && !pendingVideos.isEmpty()) {
        initialSection = "section-approvals";
    } else if ("students".equals(viewParam)) {
        initialSection = "section-students";
    }
%>

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <style>
        details > summary { list-style: none; }
        details > summary::-webkit-details-marker { display: none; }
    </style>
    <script>
        window.onpageshow = function(event) { if (event.persisted) window.location.reload(); };

        const unassignedList = [
            <% 
            if(rId == 4 && isHod) {
                boolean firstUn = true;
                for(Map<String,String> s : unassignedStudents) {
                    if(!firstUn) out.print(",");
                    out.print("{uid:'" + s.get("uid") + "', name:'" + s.get("name").replace("'", "\\'") + "', year:'" + s.get("year") + "'}");
                    firstUn = false;
                }
            } 
            %>
        ];
        
        const allFaculty = [
            <% 
            if(rId == 1) {
                boolean firstFac = true;
                for(Map<String,String> f : allFacultyList) {
                    if(!firstFac) out.print(",");
                    out.print("{uid:'" + f.get("uid") + "', name:'" + f.get("name").replace("'", "\\'") + "', dept:'" + f.get("dept") + "'}");
                    firstFac = false;
                }
            } 
            %>
        ];

        // --- AJAX PROMOTE/DEMOTE STUDENT ---
        async function updateStudentStatus(event, uid, action, btnElement) {
            event.preventDefault();
            const originalText = btnElement.innerText;
            btnElement.innerText = "...";
            btnElement.disabled = true;

            const row = btnElement.closest('.student-row');
            const currentYear = row.dataset.year;
            const currentDept = row.dataset.dept;

            let targetYear = "";
            if (action === 'promote') {
                if (currentYear === '1st') targetYear = '2nd';
                else if (currentYear === '2nd') targetYear = '3rd';
                else if (currentYear === '3rd') targetYear = '4th';
                else if (currentYear === '4th') targetYear = 'Alumni';
            } else if (action === 'demote') {
                if (currentYear === 'Alumni') targetYear = '4th';
                else if (currentYear === '4th') targetYear = '3rd';
                else if (currentYear === '3rd') targetYear = '2nd';
                else if (currentYear === '2nd') targetYear = '1st';
            }

            try {
                const formData = new URLSearchParams();
                formData.append('uid', uid);
                formData.append('action', action);

                const response = await fetch('promoteDemote', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                    body: formData.toString()
                });

                const data = await response.json();

                if (data.status === 'success') {
                    if (targetYear) {
                        const targetContainer = document.getElementById('student-list-' + currentDept + '-' + targetYear);
                        if (targetContainer) {
                            row.style.transition = 'opacity 0.3s ease, transform 0.3s ease';
                            row.style.opacity = '0';
                            row.style.transform = 'scale(0.95)';
                            setTimeout(() => {
                                targetContainer.appendChild(row);
                                row.dataset.year = targetYear;
                                const promoteBtn = row.querySelector('.promote-btn');
                                const demoteBtn = row.querySelector('.demote-btn');
                                
                                if (targetYear === 'Alumni') { 
                                    promoteBtn.disabled = true; promoteBtn.style.opacity = '0.4'; promoteBtn.style.cursor = 'not-allowed'; 
                                } else { 
                                    promoteBtn.disabled = false; promoteBtn.style.opacity = '1'; promoteBtn.style.cursor = 'pointer'; 
                                }
                                
                                if (targetYear === '1st') { 
                                    demoteBtn.disabled = true; demoteBtn.style.opacity = '0.4'; demoteBtn.style.cursor = 'not-allowed'; 
                                } else { 
                                    demoteBtn.disabled = false; demoteBtn.style.opacity = '1'; demoteBtn.style.cursor = 'pointer'; 
                                }
                                
                                btnElement.innerText = action === 'promote' ? 'Promote ↑' : '↓ Demote';
                                
                                const oldCounter = document.getElementById('count-' + currentDept + '-' + currentYear);
                                const newCounter = document.getElementById('count-' + currentDept + '-' + targetYear);
                                if (oldCounter) oldCounter.innerText = Math.max(0, parseInt(oldCounter.innerText) - 1);
                                if (newCounter) newCounter.innerText = parseInt(newCounter.innerText) + 1;
                                
                                setTimeout(() => {
                                    row.style.opacity = '1';
                                    row.style.transform = 'scale(1)';
                                }, 50);
                            }, 300);
                            return; 
                        }
                    }
                    row.style.display = 'none';
                } else {
                    alert("Update Failed: " + (data.message || "Unknown error"));
                    btnElement.innerText = originalText;
                    btnElement.disabled = false;
                }
            } catch (error) {
                console.error('Error:', error);
                alert("An error occurred. Make sure the server is running.");
                btnElement.innerText = originalText;
                btnElement.disabled = false;
            }
        }

        let draftQuestions = [];
        let formPreviewVisible = false;
        const NEXT_SURVEY_ID = <%= nextSurveyId %>; 

        function openFormBuilder() {
            document.getElementById('form-builder-modal').classList.remove('hidden');
            renderBuilderFields();
            setTimeout(() => document.getElementById('new_field_input').focus(), 100);
        }
        function closeFormBuilder() { document.getElementById('form-builder-modal').classList.add('hidden'); }

        function addFormField() {
            const input = document.getElementById('new_field_input');
            const val = input.value.trim();
            if(val !== '') {
                draftQuestions.unshift(val); 
                input.value = '';
                renderBuilderFields();
            }
        }

        function deleteFormField(index) {
            draftQuestions.splice(index, 1);
            renderBuilderFields();
        }

        function renderBuilderFields() {
            const list = document.getElementById('builder-fields-list');
            if(draftQuestions.length === 0) {
                list.innerHTML = '<p class="text-sm text-gray-400 italic text-center mt-10">No fields added yet.</p>';
                return;
            }
            let html = '';
            draftQuestions.forEach((q, idx) => {
                html += '<div class="flex justify-between items-center bg-white p-3 border rounded shadow-sm mb-2">' +
                            '<span class="font-semibold text-gray-800">' + (draftQuestions.length - idx) + '. ' + q + '</span>' +
                            '<button type="button" onclick="deleteFormField(' + idx + ')" class="text-red-500 hover:text-red-700 font-bold p-1">🗑️</button>' +
                        '</div>';
            });
            list.innerHTML = html;
        }

        function saveFormBuilder() {
            if(draftQuestions.length === 0) { alert("Please add at least one field!"); return; }
            document.getElementById('hidden_survey_questions').value = JSON.stringify(draftQuestions);
            document.getElementById('form-builder-empty').classList.add('hidden');
            document.getElementById('form-builder-summary').classList.remove('hidden');
            document.getElementById('summary-form-id').innerText = "#" + NEXT_SURVEY_ID;
            renderFormPreview();
            closeFormBuilder();
        }

        function toggleFormPreview() {
            formPreviewVisible = !formPreviewVisible;
            const list = document.getElementById('form-builder-preview-list');
            if(formPreviewVisible) list.classList.remove('hidden');
            else list.classList.add('hidden');
        }

        function renderFormPreview() {
            const list = document.getElementById('form-builder-preview-list');
            let html = '<ul class="list-disc pl-5">';
            draftQuestions.slice().reverse().forEach(q => { html += '<li class="py-1">' + q + '</li>'; });
            html += '</ul>';
            list.innerHTML = html;
        }

        function openTakeSurvey(id, title, btnElement) {
            const questionsJson = btnElement.getAttribute('data-questions');
            let questions = [];
            try { questions = JSON.parse(questionsJson).reverse(); } catch(e) {}
            
            document.getElementById('take_survey_id').value = id;
            document.getElementById('take-survey-title').innerText = title;
            
            const container = document.getElementById('take-survey-questions-container');
            container.innerHTML = '';
            
            questions.forEach((q, idx) => {
                let html = '<div class="bg-gray-50 p-4 rounded border mb-4">' +
                               '<label class="block font-bold text-gray-800 mb-3">' + (idx+1) + '. ' + q + '</label>' +
                               '<div class="flex justify-between max-w-sm mx-auto">';
                for(let i=1; i<=5; i++) {
                    html += '<label class="flex flex-col items-center cursor-pointer">' +
                                '<input type="radio" name="q' + idx + '" value="' + i + '" class="w-6 h-6 accent-blue-600 mb-1" required>' +
                                '<span class="text-xs font-bold text-gray-500">' + i + '</span>' +
                            '</label>';
                }
                html +=        '</div>' +
                           '</div>';
                container.innerHTML += html;
            });
            
            document.getElementById('take-survey-modal').classList.remove('hidden');
        }
        
        function closeTakeSurveyModal() { document.getElementById('take-survey-modal').classList.add('hidden'); }

        function submitSurveyAnswers(e) {
            e.preventDefault();
            const id = document.getElementById('take_survey_id').value;
            const form = document.getElementById('take-survey-form');
            const formData = new FormData(form);
            const params = new URLSearchParams(formData).toString();
            
            const xhr = new XMLHttpRequest();
            xhr.open("POST", "submitSurvey", true);
            xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
            xhr.onload = function() {
                alert("Ratings submitted successfully!");
                closeTakeSurveyModal();
                dismissNotification(id);
                const row = document.getElementById('survey-row-' + id);
                if(row) row.style.display = 'none';
            };
            xhr.send(params);
        }

        function openAnalysisModal(title, questionsStr, answersStr) {
            let questions = [];
            let answersList = [];
            try {
                questions = JSON.parse(questionsStr).reverse(); 
                answersList = JSON.parse(answersStr);
            } catch (e) {
                console.error("Error parsing JSON data", e);
                alert("Could not load analytics data.");
                return;
            }

            let totalSum = 0;
            let totalCount = 0;
            let questionSums = new Array(questions.length).fill(0);
            let questionCounts = new Array(questions.length).fill(0);

            answersList.forEach(ansArray => {
                if (Array.isArray(ansArray)) {
                    ansArray.forEach((val, idx) => {
                        let num = parseFloat(val);
                        if (!isNaN(num)) {
                            questionSums[idx] += num;
                            questionCounts[idx]++;
                            totalSum += num;
                            totalCount++;
                        }
                    });
                }
            });

            const overallAvg = totalCount === 0 ? "0.0" : (totalSum / totalCount).toFixed(1);

            document.getElementById('analysis-title').innerText = title + " - Analytics";
            document.getElementById('analysis-overall-score').innerText = overallAvg;
            
            let breakdownHtml = '';
            if (totalCount === 0) {
                breakdownHtml = '<p class="text-gray-500 italic text-center py-4">No responses yet to analyze.</p>';
            } else {
                questions.forEach((q, idx) => {
                    let avg = questionCounts[idx] === 0 ? 0 : (questionSums[idx] / questionCounts[idx]).toFixed(1);
                    let pct = (avg / 5) * 100;
                    
                    breakdownHtml += '<div class="mb-4">' +
                        '<div class="flex justify-between text-sm font-bold text-gray-700 mb-1">' +
                            '<span>' + (idx + 1) + '. ' + q + '</span>' +
                            '<span>⭐ ' + avg + ' / 5</span>' +
                        '</div>' +
                        '<div class="w-full bg-gray-200 rounded-full h-3">' +
                            '<div class="bg-indigo-600 h-3 rounded-full transition-all duration-500" style="width: ' + pct + '%"></div>' +
                        '</div>' +
                    '</div>';
                });
            }

            document.getElementById('analysis-breakdown').innerHTML = breakdownHtml;
            document.getElementById('analysis-modal').classList.remove('hidden');
        }

        function closeAnalysisModal() { document.getElementById('analysis-modal').classList.add('hidden'); }
        
        function openAudienceModal(title, audienceText) {
            document.getElementById('audience-modal-title').innerText = "Audience: " + title;
            document.getElementById('audience-modal-content').innerText = audienceText;
            document.getElementById('audience-modal').classList.remove('hidden');
        }
        function closeAudienceModal() { document.getElementById('audience-modal').classList.add('hidden'); }

        function showHodHints(val) {
            const box = document.getElementById('hod-hints');
            if(val.trim().length < 2) { 
                box.classList.add('hidden');
                box.innerHTML = '';
                return;
            }
            const lowerVal = val.toLowerCase();
            const matches = allFaculty.filter(f => f.name.toLowerCase().includes(lowerVal) || f.uid.toLowerCase().includes(lowerVal));
            
            if(matches.length === 0) {
                box.innerHTML = '<div class="p-3 text-sm text-gray-500 italic">No matching faculty found</div>';
                box.classList.remove('hidden');
                return;
            }

            let html = '';
            matches.forEach(f => {
                html += '<div onclick="selectHodFaculty(\'' + f.uid + '\')" class="p-3 border-b hover:bg-yellow-50 cursor-pointer transition">' +
                            '<p class="font-bold text-sm text-gray-800">' + f.name + ' <span class="font-normal text-xs text-gray-500">(' + f.dept + ')</span></p>' +
                            '<p class="text-xs text-blue-600">' + f.uid + '</p>' +
                        '</div>';
            });
            box.innerHTML = html;
            box.classList.remove('hidden');
        }

        function selectHodFaculty(uid) {
            document.getElementById('hod_faculty_uid').value = uid;
            document.getElementById('hod-hints').classList.add('hidden'); 
        }

        function renderUnassignedStudents() {
            const container = document.getElementById('unassigned_container');
            if(!container) return; 
            const checkedYears = Array.from(document.querySelectorAll('.mentor-year-filter:checked')).map(cb => cb.value);
            
            if (checkedYears.length === 0) {
                container.innerHTML = '<p class="text-gray-500 italic text-center py-4">Select at least one year to view students.</p>';
                return;
            }

            let html = '';
            checkedYears.forEach(year => {
                const studentsInYear = unassignedList.filter(s => s.year === year);
                if (studentsInYear.length > 0) {
                    html += '<div class="bg-indigo-100 text-indigo-800 font-bold px-3 py-2 rounded mt-4 mb-2 text-sm border-l-4 border-indigo-500">' + year + ' Year</div>';
                    studentsInYear.forEach(s => {
                        html += '<div class="flex items-center mb-2 p-2 hover:bg-gray-50 rounded border border-transparent hover:border-gray-200">' +
                                    '<input type="checkbox" name="student_uids" value="' + s.uid + '" class="mr-3 h-5 w-5 text-indigo-600">' +
                                    '<div><p class="font-semibold text-gray-800 text-sm">' + s.name + ' (' + s.uid + ')</p></div>' +
                                '</div>';
                    });
                } else {
                    html += '<div class="bg-gray-100 text-gray-600 font-bold px-3 py-2 rounded mt-4 mb-2 text-sm border-l-4 border-gray-400">' + year + ' Year</div>';
                    html += '<p class="text-gray-400 text-xs italic p-2">No unassigned students found.</p>';
                }
            });
            container.innerHTML = html;
        }

        function handleAddUserRoleChange() {
            const roleId = document.getElementById("add_role_id").value;
            const deptContainer = document.getElementById("add_dept_container");
            const yearContainer = document.getElementById("add_year_container");
            const deptInput = document.getElementById("add_department");
            const yearInput = document.getElementById("add_year");

            deptContainer.style.display = "block";
            deptInput.required = true;
            yearContainer.style.display = "block";
            yearInput.required = true;

            if (roleId === "1") { 
                deptContainer.style.display = "none";
                deptInput.required = false;
                deptInput.value = "";
                yearContainer.style.display = "none";
                yearInput.required = false;
                yearInput.value = "";
            } else if (roleId === "4" || roleId === "5") { 
                yearContainer.style.display = "none";
                yearInput.required = false;
                yearInput.value = "";
            }
        }

        function dismissNotification(id) {
            const notification = document.getElementById('notify-survey-' + id);
            if(notification) {
                notification.style.transition = "opacity 0.3s ease, height 0.3s ease";
                notification.style.opacity = "0";
                setTimeout(() => {
                    notification.style.display = "none";
                    const list = document.getElementById('dashboard-survey-list');
                    const visibleItems = Array.from(list.children).filter(li => li.style.display !== 'none');
                    if(visibleItems.length === 0) {
                        document.getElementById('dashboard-survey-empty').style.display = 'block';
                    }
                }, 300);
            }
        }

        function playVideo(filename) {
            const playerDiv = document.getElementById('floating-video-player');
            const videoElement = document.getElementById('floating-video-src');
            videoElement.src = 'uploaded_videos/' + filename;
            playerDiv.classList.remove('hidden');
            playerDiv.classList.add('flex');
            videoElement.play().catch(e => console.error("Autoplay failed:", e));
        }

        function closeVideo() {
            const playerDiv = document.getElementById('floating-video-player');
            const videoElement = document.getElementById('floating-video-src');
            videoElement.pause();
            videoElement.src = "";
            playerDiv.classList.add('hidden');
            playerDiv.classList.remove('flex');
        }

        function showSection(sectionId) {
            const sections = ['section-dashboard', 'section-profile', 'section-push', 'section-ask-video', 'section-uploads', 'section-analysis', 'section-students', 'section-classroom', 'section-approvals', 'section-assign-mentor', 'section-password-reset', 'section-assign-hod', 'section-add-student'];
            sections.forEach(id => {
                const el = document.getElementById(id);
                if(el) el.classList.add('hidden');
            });
            document.querySelectorAll('.nav-btn').forEach(btn => {
                btn.classList.remove('bg-blue-600');
                btn.classList.add('hover:bg-gray-700');
            });
            const target = document.getElementById(sectionId);
            if(target) target.classList.remove('hidden');
            
            let btnId = 'btn-' + sectionId.replace('section-', '');
            if(sectionId !== 'section-add-student' && sectionId !== 'section-password-reset' && sectionId !== 'section-assign-hod') {
               const activeBtn = document.getElementById(btnId);
               if(activeBtn) {
                   activeBtn.classList.remove('hover:bg-gray-700');
                   activeBtn.classList.add('bg-blue-600');
               }
            }
        }

        function toggleUserMenu() {
            const menu = document.getElementById('user-menu-submenu');
            menu.classList.toggle('hidden');
        }

        const allStudents = <%= studentJson.toString() %>;
        function updateStudentList(wrapperId) {
            const wrapper = document.getElementById(wrapperId);
            const enableSpecific = wrapper.querySelector('.enable-specific-checkbox').checked;
            const listWrapper = wrapper.querySelector('.student-list-wrapper');
            const containerBox = wrapper.querySelector('.student-checkbox-container');
            if (!enableSpecific) { listWrapper.classList.add('hidden'); containerBox.innerHTML = ''; return; }
            listWrapper.classList.remove('hidden');
            const selectedDepts = Array.from(wrapper.querySelectorAll('input[name="target_dept"]:checked')).map(cb => cb.value);
            const selectedYears = Array.from(wrapper.querySelectorAll('input[name="target_year"]:checked')).map(cb => cb.value);
            const filtered = allStudents.filter(s => {
                const deptMatch = selectedDepts.includes('All') || selectedDepts.includes(s.dept);
                const yearMatch = selectedYears.includes('All') || selectedYears.includes(s.year);
                return deptMatch && yearMatch;
            });
            containerBox.innerHTML = '';
            if(filtered.length === 0) { containerBox.innerHTML = '<div class="text-xs text-gray-500 italic p-2">No matching students found</div>'; return; }
            filtered.forEach(s => {
                const div = document.createElement('div');
                div.className = 'flex items-center mb-1';
                div.innerHTML = '<input type="checkbox" name="target_user" value="' + s.uid + '" class="mr-2 h-4 w-4"> <label class="text-sm">' + s.name + ' (' + s.uid + ')</label>';
                containerBox.appendChild(div);
            });
        }
        function toggleAll(type, isAll, wrapperId) {
            const wrapper = document.getElementById(wrapperId);
            const checkboxes = wrapper.querySelectorAll('input[name="target_' + type + '"]');
            if(isAll) checkboxes.forEach(cb => { if(cb.value !== 'All') cb.checked = false; });
            else wrapper.querySelector('input[name="target_' + type + '"][value="All"]').checked = false;
            updateStudentList(wrapperId);
        }
        
        function openEditModal(listId, mentorName) {
            document.getElementById('edit-modal').classList.remove('hidden');
            document.getElementById('modal-mentor-name').innerText = mentorName;
            document.querySelectorAll('.edit-list').forEach(el => el.classList.add('hidden'));
            const targetList = document.getElementById(listId); 
            if(targetList) targetList.classList.remove('hidden');
        }
        function closeEditModal() { document.getElementById('edit-modal').classList.add('hidden'); }
        
        function openPassModal() { document.getElementById('password-modal').classList.remove('hidden'); }
        function closePassModal() { document.getElementById('password-modal').classList.add('hidden'); }
        
        function openAdminResetModal(username) {
            document.getElementById('admin-reset-modal').classList.remove('hidden');
            document.getElementById('target-user-input').value = username;
            document.getElementById('reset-username-display').innerText = username;
        }
        function closeAdminResetModal() { document.getElementById('admin-reset-modal').classList.add('hidden'); }

        function fetchUserSuggestions(val) {
            const box = document.getElementById('search-suggestions');
            if(val.length < 2) {
                box.classList.add('hidden');
                box.innerHTML = '';
                return;
            }
            const xhr = new XMLHttpRequest();
            xhr.open('POST', 'AdminUserAction?action=suggest&q=' + encodeURIComponent(val), true);
            xhr.onload = function() {
                if(this.status === 200) {
                    box.innerHTML = this.responseText;
                    if(this.responseText.trim() !== '') box.classList.remove('hidden'); else box.classList.add('hidden');
                }
            };
            xhr.send();
        }

        function selectUser(uid) {
            document.getElementById('search-input').value = uid;
            document.getElementById('hidden-search-query').value = uid; 
            document.getElementById('search-suggestions').classList.add('hidden');
            document.getElementById('search-form').submit(); 
        }
    </script>
</head>
<body class="bg-gray-100 font-sans" onload="initPage()">
    <div class="flex h-screen overflow-hidden">
        <div class="w-64 bg-gray-900 text-white flex flex-col shadow-xl z-20">
            <div class="p-6 border-b border-gray-700 flex flex-col items-center">
                <div class="h-16 w-16 bg-gray-700 rounded-full flex items-center justify-center mb-3 border-2 border-blue-500"><span class="text-2xl">👤</span></div>
                <h2 class="font-semibold text-lg text-center"><%= userName %></h2>
                <span class="text-xs text-gray-400 uppercase tracking-wider">
                    <% 
                    if(rId == 1) out.print("Administrator"); 
                    else if(rId == 3) out.print("Mentor"); 
                    else if(rId == 4 && isHod) out.print("Head of Dept"); 
                    else if(rId == 4) out.print("Faculty");
                    else if(rId == 5) out.print("Alumni");
                    else out.print("Student"); 
                    %>
                </span>
            </div>
            <nav class="flex-1 px-4 py-6 space-y-2 overflow-y-auto">
                <button id="btn-dashboard" onclick="showSection('section-dashboard')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition bg-blue-600">📊 Dashboard</button>
                <button id="btn-profile" onclick="showSection('section-profile')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">Profile</button>
                
                <button id="btn-analysis" onclick="showSection('section-analysis')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">
                    <% if (rId == 2 || rId == 5) { %> 📝 Surveys <% } else { %> 📈 Analysis <% } %>
                </button>
                
                <button id="btn-classroom" onclick="showSection('section-classroom')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">📺 Video Gallery</button>
                
                <% if ((rId == 1 || rId == 3 || rId == 4) && !pendingVideos.isEmpty()) { %>
                <button id="btn-approvals" onclick="showSection('section-approvals')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition bg-red-600 animate-pulse hover:bg-red-700">⚠️ Approvals (<%= pendingVideos.size() %>)</button>
                <% } %>
                
                <% if (rId == 1 || (rId == 4 && isHod)) { %>
                <button id="btn-students" onclick="showSection('section-students')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">🎓 Students List</button>
                <% } %>
                
                <% if (rId == 4 && isHod) { %>
                <button id="btn-assign-mentor" onclick="showSection('section-assign-mentor')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">👥 Assign Mentors</button>
                <% } %>

                <% if (rId == 1 || rId == 3 || rId == 4) { %>
                <button id="btn-push" onclick="showSection('section-push')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">Push Survey</button>
                <button id="btn-ask-video" onclick="showSection('section-ask-video')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">Ask for Video</button>
                <% } %>
                
                <% if (rId == 1) { %>
                <button id="btn-uploads" onclick="showSection('section-uploads')" class="nav-btn w-full flex items-center px-4 py-3 rounded text-left transition hover:bg-gray-700">Upload Data</button>
                
                <button onclick="toggleUserMenu()" class="nav-btn w-full flex items-center justify-between px-4 py-3 rounded text-left transition hover:bg-gray-700">
                    <span>🛠️ Users Management</span> <span>▼</span>
                </button>
                <div id="user-menu-submenu" class="hidden pl-6 space-y-1 bg-gray-800 py-2 rounded">
                    <button onclick="showSection('section-add-student')" class="w-full text-left text-sm text-gray-300 hover:text-white py-1">➕ Add User</button>
                    <button onclick="showSection('section-password-reset')" class="w-full text-left text-sm text-gray-300 hover:text-white py-1">🔑 Password Reset</button>
                    <button onclick="showSection('section-assign-hod')" class="w-full text-left text-sm text-gray-300 hover:text-white py-1">👑 Assign HOD</button>
                </div>
                <% } %>
            </nav>
            <div class="p-4 border-t border-gray-800"><a href="logout" class="flex items-center justify-center w-full px-4 py-2 bg-red-600 hover:bg-red-700 rounded text-sm font-semibold transition">Log Out</a></div>
        </div>

        <div class="flex-1 bg-gray-100 flex flex-col h-screen overflow-hidden relative">
            
            <% if(urlMsg != null) { 
                boolean isError = urlMsg.startsWith("Error");
                String alertClass = isError ? "bg-red-100 border-l-4 border-red-500 text-red-700" : "bg-green-100 border-l-4 border-green-500 text-green-700";
            %>
            <div class="<%= alertClass %> p-4 m-4 shadow-md rounded relative" role="alert">
                <p class="font-bold"><%= isError ? "Error" : "Success" %></p>
                <p><%= urlMsg.replace("Error:", "").replace("Success:", "") %></p>
                <button onclick="this.parentElement.style.display='none'" class="absolute top-0 bottom-0 right-0 px-4 py-3 text-2xl font-bold">&times;</button>
            </div>
            <% } %>

            <div class="flex-1 overflow-y-auto p-10">

                <div id="section-dashboard" class="fade-in">
                    <div class="mb-8"><h1 class="text-3xl font-bold text-gray-800">Welcome, <%= userName %>! 👋</h1><p class="text-gray-600">Here is what's new for you today.</p></div>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-8">
                        
                        <% if (rId == 2 || rId == 5) { %>
                        <div class="bg-white rounded-xl shadow-lg overflow-hidden border-t-4 border-blue-500">
                            <div class="p-6 border-b bg-gray-50 flex justify-between items-center"><h3 class="text-xl font-bold text-gray-800 flex items-center">📢 Recent Notices</h3>
                                <span class="bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded-full font-bold"><%= dashboardSurveys.size() %> New</span>
                            </div>
                            <div class="p-6">
                                <ul id="dashboard-survey-list" class="space-y-4">
                                    <% for(Map<String,String> item : dashboardSurveys) { %>
                                    <li id="notify-survey-<%= item.get("id") %>" class="flex justify-between items-center pb-3 border-b border-gray-100 last:border-0">
                                        <div class="flex items-start"><span class="text-2xl mr-3">📌</span><div><p class="font-semibold text-gray-800 text-sm"><%= item.get("desc") %></p><p class="text-xs text-gray-500 mt-1">By <%= item.get("by") %> • <%= item.get("time") %></p></div></div>
                                        <button type="button" data-questions="<%= item.get("questions") %>" onclick="openTakeSurvey('<%= item.get("id") %>', '<%= item.get("desc") %>', this)" class="px-4 py-2 bg-indigo-600 text-white text-xs font-bold rounded hover:bg-indigo-700">Open Form</button>
                                    </li>
                                    <% } %>
                                </ul>
                                <p id="dashboard-survey-empty" class="text-gray-500 italic text-center py-4" style="<%= dashboardSurveys.isEmpty() ? "display:block" : "display:none" %>">No new notices.</p>
                                <button onclick="showSection('section-analysis')" class="mt-6 w-full py-2 bg-blue-50 text-blue-600 font-bold rounded hover:bg-blue-100 transition">View Surveys →</button>
                            </div>
                        </div>
                        
                        <div class="bg-white rounded-xl shadow-lg overflow-hidden border-t-4 border-pink-500">
                            <div class="p-6 border-b bg-gray-50 flex justify-between items-center"><h3 class="text-xl font-bold text-gray-800 flex items-center">🎥 Video Tasks</h3><span class="bg-pink-100 text-pink-800 text-xs px-2 py-1 rounded-full font-bold"><%= dashboardTasks.size() %> New</span></div>
                            <div class="p-6">
                                <% if(dashboardTasks.isEmpty()) { %><p class="text-gray-500 italic text-center py-4">No pending video requests.</p><% } else { %>
                                    <ul class="space-y-4">
                                        <% for(Map<String,String> item : dashboardTasks) { %>
                                        <li class="flex items-start pb-3 border-b border-gray-100 last:border-0"><span class="text-2xl mr-3">🎬</span><div><p class="font-semibold text-gray-800 text-sm"><%= item.get("desc") %></p><p class="text-xs text-gray-500 mt-1">By <%= item.get("by") %> • <%= item.get("time") %></p></div></li>
                                        <% } %>
                                    </ul>
                                <% } %>
                                <button onclick="showSection('section-classroom')" class="mt-6 w-full py-2 bg-pink-50 text-pink-600 font-bold rounded hover:bg-pink-100 transition">Go to Video Gallery →</button>
                            </div>
                        </div>
                        <% } else { %>
                        <div class="bg-white rounded-xl shadow-lg overflow-hidden border-t-4 border-blue-500">
                            <div class="p-6 border-b bg-gray-50 flex justify-between items-center"><h3 class="text-xl font-bold text-gray-800 flex items-center">📢 My Recent Surveys</h3></div>
                            <div class="p-6">
                                <% 
                                boolean hasMySurveys = false;
                                for (Map.Entry<String, List<Map<String,String>>> entry : groupedPushHistory.entrySet()) {
                                    if (entry.getKey().contains(userName)) {
                                        hasMySurveys = true;
                                        out.print("<ul class='space-y-4'>");
                                        int limit = 0;
                                        for (Map<String,String> item : entry.getValue()) {
                                            if (limit++ >= 5) break;
                                %>
                                        <li class="flex justify-between items-center pb-3 border-b border-gray-100 last:border-0">
                                            <div class="flex items-start"><span class="text-2xl mr-3">📌</span><div><p class="font-semibold text-gray-800 text-sm"><%= item.get("desc") %></p><p class="text-xs text-gray-500 mt-1"><%= item.get("date") %></p></div></div>
                                            <div class="flex gap-2">
                                                <button type="button" onclick="openAudienceModal('<%= item.get("desc").replace("'", "\\'") %>', '<%= item.get("audience").replace("'", "\\'") %>')" class="px-3 py-1 bg-gray-100 text-gray-600 border border-gray-300 text-xs font-bold rounded hover:bg-gray-200" title="View Audience">👥</button>
                                                <button type="button" onclick="openAnalysisModal('<%= item.get("desc").replace("'", "\\'") %>', '<%= item.get("questions") %>', '<%= item.get("all_answers") %>')" class="px-3 py-1 bg-indigo-600 text-white text-xs font-bold rounded hover:bg-indigo-700">Analytics</button>
                                            </div>
                                        </li>
                                <%
                                        }
                                        out.print("</ul>");
                                    }
                                }
                                if(!hasMySurveys) { out.print("<p class='text-gray-500 italic text-center py-4'>You haven't pushed any surveys yet.</p>"); }
                                %>
                                <button onclick="showSection('section-analysis')" class="mt-6 w-full py-2 bg-blue-50 text-blue-600 font-bold rounded hover:bg-blue-100 transition">View Full Analysis Dashboard →</button>
                            </div>
                        </div>
                        
                        <div class="bg-white rounded-xl shadow-lg overflow-hidden border-t-4 border-pink-500">
                            <div class="p-6 border-b bg-gray-50 flex justify-between items-center"><h3 class="text-xl font-bold text-gray-800 flex items-center">🎥 My Recent Video Tasks</h3></div>
                            <div class="p-6">
                                <% 
                                boolean hasMyTasks = false;
                                for (Map.Entry<String, List<Map<String,String>>> entry : groupedTaskHistory.entrySet()) {
                                    if (entry.getKey().contains(userName)) {
                                        hasMyTasks = true;
                                        out.print("<ul class='space-y-4'>");
                                        int limit = 0;
                                        for (Map<String,String> item : entry.getValue()) {
                                            if (limit++ >= 5) break;
                                            boolean isActive = "Active".equals(item.get("status"));
                                            String statusBadge = isActive ? "text-green-600" : "text-gray-400";
                                %>
                                        <li class="flex justify-between items-center pb-3 border-b border-gray-100 last:border-0">
                                            <div class="flex items-start"><span class="text-2xl mr-3">🎬</span><div><p class="font-semibold text-gray-800 text-sm"><%= item.get("desc") %></p><p class="text-xs font-bold mt-1 <%= statusBadge %>"><%= item.get("status") %></p></div></div>
                                            <div class="flex gap-2">
                                                <button type="button" onclick="openAudienceModal('<%= item.get("desc").replace("'", "\\'") %>', '<%= item.get("audience").replace("'", "\\'") %>')" class="px-3 py-1 bg-gray-100 text-gray-600 border border-gray-300 text-xs font-bold rounded hover:bg-gray-200" title="View Audience">👥</button>
                                                <form action="videoAction" method="post" onsubmit="return confirm('WARNING: Deleting this task will permanently delete all submitted videos associated with it. Continue?');">
                                                    <input type="hidden" name="id" value="<%= item.get("id") %>">
                                                    <input type="hidden" name="action" value="deleteRequest">
                                                    <input type="hidden" name="view" value="dashboard">
                                                    <button type="submit" class="px-3 py-1 bg-red-50 text-red-600 border border-red-200 text-xs font-bold rounded hover:bg-red-600 hover:text-white transition">Delete</button>
                                                </form>
                                            </div>
                                        </li>
                                <%
                                        }
                                        out.print("</ul>");
                                    }
                                }
                                if(!hasMyTasks) { out.print("<p class='text-gray-500 italic text-center py-4'>You haven't requested any videos yet.</p>"); }
                                %>
                                <button onclick="showSection('section-classroom')" class="mt-6 w-full py-2 bg-pink-50 text-pink-600 font-bold rounded hover:bg-pink-100 transition">View Video Gallery →</button>
                            </div>
                        </div>
                        <% } %>
                    </div>
                </div>

                <div id="section-profile" class="hidden"><div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-purple-500 max-w-2xl mx-auto"><div class="flex justify-between items-center mb-6"><h2 class="text-2xl font-bold text-gray-800">👤 My Profile</h2><button onclick="openPassModal()" class="bg-gray-200 text-gray-700 px-3 py-1 rounded text-sm hover:bg-gray-300">Change Password</button></div><div class="space-y-6"><div class="flex justify-between border-b pb-4"><span class="text-gray-600">Name</span><span class="font-bold"><%= userName %></span></div><div class="flex justify-between border-b pb-4"><span class="text-gray-600">ID / Roll No</span><span class="font-bold"><%= myRoll %></span></div><div class="flex justify-between border-b pb-4"><span class="text-gray-600">Role</span><span class="font-bold text-blue-600"><% if(rId == 1) out.print("Administrator"); else if(rId == 3) out.print("Mentor"); else if(rId == 4 && isHod) out.print("Head of Dept"); else if(rId == 4) out.print("Faculty"); else if(rId == 5) out.print("Alumni"); else out.print("Student"); %></span></div><% if(rId == 2) { %><div class="flex justify-between border-b pb-4"><span class="text-gray-600">My Mentor</span><span class="font-bold text-green-600"><%= myMentorName %></span></div><% } %><% if(rId == 2 || rId == 3 || rId == 4 || rId == 5) { %><div class="flex justify-between border-b pb-4"><span class="text-gray-600">Dept</span><span class="font-bold"><%= myDept %></span></div><% if(rId != 3 && rId != 4 && rId != 5) { %><div class="flex justify-between border-b pb-4"><span class="text-gray-600">Year</span><span class="font-bold"><%= myYear %></span></div><% } %><% } %></div></div></div>

                <% if (rId == 1 || (rId == 4 && isHod)) { %>
                <div id="section-students" class="hidden">
                    <div class="max-w-6xl mx-auto space-y-6">
                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-indigo-600 mb-6">
                            <h2 class="text-3xl font-bold text-gray-800">🎓 Students List</h2>
                            <p class="text-gray-500 mt-2">Manage student records and class promotions.</p>
                        </div>

                        <% if (rId == 1) { 
                            for(String dName : allStudentsMap.keySet()) {
                                Map<String, List<Map<String,String>>> yearMap = allStudentsMap.get(dName);
                                int deptTotal = 0; for(List l : yearMap.values()) deptTotal += l.size();
                        %>
                            <details class="bg-white rounded-lg shadow-sm border border-gray-200 group mb-4">
                                <summary class="p-5 cursor-pointer font-bold bg-gray-50 hover:bg-gray-100 flex justify-between items-center outline-none list-none rounded-t-lg transition">
                                    <div class="flex items-center gap-3"><span class="text-xl">🏢</span> <span class="text-lg"><%= dName %> Department</span></div>
                                    <div class="flex items-center gap-3">
                                        <span class="bg-indigo-100 text-indigo-800 text-xs px-3 py-1 rounded-full"><%= deptTotal %> Users</span>
                                        <span class="text-gray-400 group-open:rotate-180 transition-transform">▼</span>
                                    </div>
                                </summary>
                                <div class="p-6 bg-white space-y-4">
                                    <% for(String yName : YEAR_ORDER) { 
                                        List<Map<String,String>> students = yearMap.get(yName);
                                    %>
                                        <details class="bg-white rounded border border-gray-200 group/year">
                                            <summary class="p-3 cursor-pointer font-bold bg-blue-50 hover:bg-blue-100 flex justify-between items-center outline-none list-none text-sm transition">
                                                <span>📚 <%= yName %> Year / Status</span>
                                                <div class="flex items-center gap-3">
                                                    <span class="bg-blue-200 text-blue-800 text-xs px-2 py-0.5 rounded-full" id="count-<%= dName.replaceAll("\\s+","") %>-<%= yName %>"><%= students.size() %></span>
                                                    <span class="text-gray-400 group-open/year:rotate-180 transition-transform">▼</span>
                                                </div>
                                            </summary>
                                            <div class="p-4 bg-white flex flex-col gap-2 min-h-[50px]" id="student-list-<%= dName.replaceAll("\\s+","") %>-<%= yName %>">
                                                <% for(Map<String,String> student : students) { %>
                                                    <div class="student-row flex flex-col md:flex-row md:items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded hover:bg-white shadow-sm transition gap-4" data-dept="<%= dName.replaceAll("\\s+","") %>" data-year="<%= yName %>">
                                                        <div class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-4 items-center text-sm">
                                                            <div class="font-bold text-gray-800 truncate" title="<%= student.get("name") %>">👤 <%= student.get("name") %></div>
                                                            <div class="text-gray-600 truncate">🆔 <%= student.get("uid") %></div>
                                                            <div class="text-gray-600 truncate">🎓 Roll: <%= student.get("roll") %></div>
                                                        </div>
                                                        <div class="flex gap-2 shrink-0">
                                                            <button type="button" onclick="updateStudentStatus(event, '<%= student.get("uid") %>', 'demote', this)" class="demote-btn bg-red-100 text-red-700 px-3 py-1.5 rounded text-xs font-bold hover:bg-red-600 hover:text-white transition shadow-sm" <%= ("1st".equals(yName)) ? "disabled style='opacity:0.4; cursor:not-allowed;'" : "" %>>↓ Demote</button>
                                                            <button type="button" onclick="updateStudentStatus(event, '<%= student.get("uid") %>', 'promote', this)" class="promote-btn bg-green-100 text-green-700 px-3 py-1.5 rounded text-xs font-bold hover:bg-green-600 hover:text-white transition shadow-sm" <%= ("Alumni".equals(yName)) ? "disabled style='opacity:0.4; cursor:not-allowed;'" : "" %>>Promote ↑</button>
                                                        </div>
                                                    </div>
                                                <% } %>
                                            </div>
                                        </details>
                                    <% } %>
                                </div>
                            </details>
                        <% } } else if (rId == 4 && isHod) { 
                            Map<String, List<Map<String,String>>> yearMap = allStudentsMap.get(myDept);
                            if (yearMap == null) { out.print("<p>No students found for this department.</p>"); } else {
                            for(String yName : YEAR_ORDER) { 
                                List<Map<String,String>> students = yearMap.get(yName);
                        %>
                            <details class="bg-white rounded-lg shadow-sm border border-gray-200 group mb-4">
                                <summary class="p-5 cursor-pointer font-bold bg-blue-50 hover:bg-blue-100 flex justify-between items-center outline-none list-none rounded-t-lg transition">
                                    <div class="flex items-center gap-3"><span class="text-xl">📚</span> <span class="text-lg"><%= yName %> Year / Status</span></div>
                                    <div class="flex items-center gap-3">
                                        <span class="bg-blue-200 text-blue-800 text-xs px-3 py-1 rounded-full font-bold"><span id="count-<%= myDept.replaceAll("\\s+","") %>-<%= yName %>"><%= students.size() %></span> Users</span>
                                        <span class="text-gray-400 group-open:rotate-180 transition-transform text-lg">▼</span>
                                    </div>
                                </summary>
                                <div class="p-6 bg-white flex flex-col gap-2 min-h-[50px]" id="student-list-<%= myDept.replaceAll("\\s+","") %>-<%= yName %>">
                                    <% for(Map<String,String> student : students) { %>
                                        <div class="student-row flex flex-col md:flex-row md:items-center justify-between p-3 bg-gray-50 border border-gray-200 rounded hover:bg-white shadow-sm transition gap-4" data-dept="<%= myDept.replaceAll("\\s+","") %>" data-year="<%= yName %>">
                                            <div class="flex-1 grid grid-cols-1 md:grid-cols-3 gap-4 items-center text-sm">
                                                <div class="font-bold text-gray-800 truncate" title="<%= student.get("name") %>">👤 <%= student.get("name") %></div>
                                                <div class="text-gray-600 truncate">🆔 <%= student.get("uid") %></div>
                                                <div class="text-gray-600 truncate">🎓 Roll: <%= student.get("roll") %></div>
                                            </div>
                                            <div class="flex gap-2 shrink-0">
                                                <button type="button" onclick="updateStudentStatus(event, '<%= student.get("uid") %>', 'demote', this)" class="demote-btn bg-red-100 text-red-700 px-3 py-1.5 rounded text-xs font-bold hover:bg-red-600 hover:text-white transition shadow-sm" <%= ("1st".equals(yName)) ? "disabled style='opacity:0.4; cursor:not-allowed;'" : "" %>>↓ Demote</button>
                                                <button type="button" onclick="updateStudentStatus(event, '<%= student.get("uid") %>', 'promote', this)" class="promote-btn bg-green-100 text-green-700 px-3 py-1.5 rounded text-xs font-bold hover:bg-green-600 hover:text-white transition shadow-sm" <%= ("Alumni".equals(yName)) ? "disabled style='opacity:0.4; cursor:not-allowed;'" : "" %>>Promote ↑</button>
                                            </div>
                                        </div>
                                    <% } %>
                                </div>
                            </details>
                        <% } } } %>
                    </div>
                </div>
                <% } %>

                <div id="section-analysis" class="hidden">
                    <div class="max-w-6xl mx-auto space-y-8">
                        
                        <% if (rId == 2 || rId == 5) { %>
                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-blue-500">
                            <h2 class="text-2xl font-bold text-gray-800 mb-6">📢 Active Surveys</h2>
                            <div class="space-y-4">
                                <% if(con != null) { try { Statement stmt = con.createStatement(); ResultSet rs = stmt.executeQuery("SELECT * FROM feedback_links ORDER BY id DESC LIMIT 50"); while(rs.next()) { 
                                    int lId = rs.getInt("id");
                                    String tDepts = rs.getString("target_dept"); String tYears = rs.getString("target_year"); String tUsers = rs.getString("target_user"); String postedBy = rs.getString("posted_by"); boolean show = false; 
                                    
                                    boolean deptMatch = tDepts.equals("All") || tDepts.contains(myDept); 
                                    boolean yearMatch = false;
                                    if (rId == 5) { yearMatch = tYears.contains("Alumni"); } else { yearMatch = tYears.equals("All") || tYears.contains(myYear); }
                                    boolean userMatch = tUsers != null && tUsers.contains(myUid); 
                                    if ((deptMatch && yearMatch) || userMatch) show = true;
                                    
                                    if(show) { 
                                        String questions = "[]"; 
                                        try { 
                                            questions = rs.getString("questions"); 
                                            if(questions==null) questions="[]";
                                        } catch(Exception e) {}
                                %>
                                    <div id="survey-row-<%= lId %>" class="flex items-center justify-between p-4 bg-gray-50 border border-gray-200 rounded hover:shadow-sm transition">
                                        <div>
                                            <h4 class="font-bold text-lg text-gray-800 flex items-center">
                                                <%= rs.getString("description") %>
                                            </h4>
                                            <p class="text-sm text-gray-500 mt-1">By: <%= rs.getString("posted_by") %> • <%= sdf.format(rs.getTimestamp("created_at")) %></p>
                                        </div>
                                        
                                        <button type="button" data-questions="<%= questions.replace("\"", "&quot;") %>" onclick="openTakeSurvey('<%= lId %>', '<%= rs.getString("description") %>', this)" class="px-5 py-2 bg-indigo-600 hover:bg-indigo-700 text-white rounded text-sm font-bold">Open Form</button>
                                    </div>
                                <% }} } catch(Exception e) { } } %>
                            </div>
                        </div>
                        <% } %>

                        <% if (rId == 1 || rId == 3 || rId == 4) { %>
                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-indigo-500">
                            <h3 class="text-2xl font-bold text-gray-800 mb-6">📊 Survey Analytics Dashboard</h3>
                            <% if(groupedPushHistory.isEmpty()) { %><p class="text-gray-500 italic">No surveys pushed yet.</p><% } else { %>
                            <div class="space-y-4">
                                <% for(Map.Entry<String, List<Map<String,String>>> entry : groupedPushHistory.entrySet()) { 
                                    String rolePoster = entry.getKey();
                                    List<Map<String,String>> posterSurveys = entry.getValue();
                                    String safeId = "group-" + Math.abs(rolePoster.hashCode());
                                %>
                                <details class="border rounded-lg bg-white overflow-hidden shadow-sm group">
                                    <% if (rId == 1 || (rId == 4 && isHod)) { %>
                                    <summary class="w-full text-left p-4 bg-gray-50 hover:bg-gray-100 flex justify-between items-center font-bold text-gray-800 border-b cursor-pointer list-none outline-none">
                                        <span>👤 <%= rolePoster %> (<%= posterSurveys.size() %> Surveys)</span>
                                        <span class="text-indigo-600 font-bold group-open:rotate-180 transition-transform">▼</span>
                                    </summary>
                                    <% } %>
                                    
                                    <div class="overflow-x-auto <%= (rId == 1 || (rId == 4 && isHod)) ? "hidden group-open:block" : "block" %>">
                                        <table class="min-w-full text-sm text-left text-gray-500">
                                            <thead class="text-xs text-gray-700 uppercase bg-gray-50 border-b">
                                                <tr>
                                                    <th class="px-6 py-3">Survey Title</th>
                                                    <th class="px-6 py-3">Date</th>
                                                    <th class="px-6 py-3">Responses</th>
                                                    <th class="px-6 py-3 text-right">Actions</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                            <% for(Map<String,String> h : posterSurveys) { %>
                                            <tr class="bg-white border-b hover:bg-gray-50 transition">
                                                <td class="px-6 py-4 font-medium text-gray-900">
                                                    <%= h.get("desc") %>
                                                </td>
                                                <td class="px-6 py-4"><%= h.get("date") %></td>
                                                <td class="px-6 py-4">
                                                    <span class="bg-indigo-100 text-indigo-800 text-xs px-3 py-1 rounded-full font-bold">
                                                        👥 <%= h.get("response_count") %>
                                                    </span>
                                                </td>
                                                <td class="px-6 py-4 flex gap-2 justify-end">
                                                    <button type="button" onclick="openAudienceModal('<%= h.get("desc").replace("'", "\\'") %>', '<%= h.get("audience").replace("'", "\\'") %>')" class="px-3 py-1.5 bg-gray-100 text-gray-600 border border-gray-300 text-xs font-bold rounded hover:bg-gray-200" title="View Audience">👥 Info</button>
                                                    <button type="button" 
                                                            onclick="openAnalysisModal('<%= h.get("desc").replace("'", "\\'") %>', '<%= h.get("questions") %>', '<%= h.get("all_answers") %>')" 
                                                            class="bg-indigo-600 text-white hover:bg-indigo-700 font-bold text-xs px-3 py-1.5 rounded shadow">
                                                        View Analytics 📈
                                                    </button>
                                                    <form action="ManageLinkServlet" method="post" onsubmit="return confirm('Delete this survey and all responses?');" style="display:inline;">
                                                        <input type="hidden" name="action" value="delete">
                                                        <input type="hidden" name="id" value="<%= h.get("id") %>">
                                                        <button type="submit" class="text-red-600 hover:text-red-800 font-bold text-xs border border-red-600 px-3 py-1.5 rounded hover:bg-red-50">
                                                            Delete 🗑️
                                                        </button>
                                                    </form>
                                                </td>
                                            </tr>
                                            <% } %>
                                        </tbody></table>
                                    </div>
                                </details>
                                <% } %>
                            </div>
                            <% } %>
                        </div>
                        <% } %>
                    </div>
                </div>

                <div id="section-classroom" class="hidden">
                    <div class="grid grid-cols-1 gap-6">
                        
                        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                            <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-indigo-500 text-center flex flex-col justify-center items-center">
                                <h2 class="text-2xl font-bold text-gray-800 mb-4">📺 Video Gallery</h2>
                                <p class="text-gray-600 mb-6">Access approved recorded lectures and assignments.</p>
                                <a href="VideoGalleryServlet" target="_blank" class="inline-block px-8 py-4 bg-indigo-600 text-white rounded-lg font-bold text-lg hover:bg-indigo-700 hover:scale-105 transition shadow-lg">
                                    <% if (rId == 2 || rId == 5) { out.print("Lectures 🚀"); } else { out.print("Open Gallery 🚀"); } %>
                                </a>
                            </div>
                            
                            <% if (rId == 1 || rId == 3 || rId == 4) { %>
                            <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-green-500">
                                <h3 class="text-xl font-bold text-gray-800 mb-4">📤 Upload Generic Video</h3>
                                <form action="UploadVideoServlet" method="post" enctype="multipart/form-data" class="flex flex-col gap-4">
                                    <div><label class="block text-gray-700 font-bold mb-2">Video Title</label><input type="text" name="title" class="w-full p-2 border rounded" required></div>
                                    <div><label class="block text-gray-700 font-bold mb-2">Select MP4</label><input type="file" name="videoFile" accept="video/mp4" class="w-full p-2 border rounded bg-gray-50" required></div>
                                    <button type="submit" class="w-full bg-green-600 text-white py-2 rounded font-bold hover:bg-green-700 transition">Upload Video</button>
                                </form>
                            </div>
                            <% } %>
                        </div>
                        
                        <% if (rId == 2 || rId == 5) { %>
                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-yellow-500">
                            <h3 class="text-xl font-bold text-gray-800 mb-6">📝 Requested Videos (Tasks)</h3>
                            <div class="space-y-6">
                                <% boolean hasTasks = false; if(con != null) { try { Statement stmtT = con.createStatement(); ResultSet rsT = stmtT.executeQuery("SELECT * FROM video_requests ORDER BY id DESC LIMIT 20"); while(rsT.next()) { if(completedTasks.contains(rsT.getInt("id"))) continue; String tDepts = rsT.getString("target_dept"); String tYears = rsT.getString("target_year"); String tUsers = rsT.getString("target_user"); boolean deptMatch = tDepts.equals("All") || tDepts.contains(myDept); boolean yearMatch = false; if (rId == 5) { yearMatch = tYears.contains("Alumni"); } else { yearMatch = tYears.equals("All") || tYears.contains(myYear); } boolean userMatch = tUsers.contains(myUid); if ((deptMatch && yearMatch) || userMatch) { hasTasks = true; 
                                    Timestamp exp = rsT.getTimestamp("expiry_date");
                                    boolean active = true;
                                    String expText = "No Expiry Limit";
                                    if(exp != null) {
                                        active = exp.after(new java.util.Date());
                                        expText = sdf.format(exp);
                                    }
                                %>
                                <div class="border <%= active ? "border-yellow-200 bg-yellow-50" : "border-red-200 bg-red-50" %> p-4 rounded-lg animate-fade-in">
                                    <div class="flex justify-between items-start mb-3">
                                        <div>
                                            <span class="<%= active ? "bg-yellow-200 text-yellow-800" : "bg-red-200 text-red-800" %> text-xs px-2 py-1 rounded font-bold uppercase"><%= active ? "Task Active" : "Task Expired" %></span>
                                            <h4 class="text-lg font-bold mt-1"><%= rsT.getString("description") %></h4>
                                            <p class="text-xs text-gray-500">Requested by: <%= rsT.getString("posted_by") %> | Expires: <%= expText %></p>
                                        </div>
                                    </div>
                                    <% if (active) { %>
                                    <form action="UploadVideoServlet" method="post" enctype="multipart/form-data" class="flex items-end gap-3 mt-2">
                                        <input type="hidden" name="requestId" value="<%= rsT.getInt("id") %>">
                                        <div class="flex-1"><label class="text-xs font-bold text-gray-600 block mb-1">Your Video Title</label><input type="text" name="title" class="w-full p-2 border rounded text-sm" placeholder="e.g. My Assignment" required></div>
                                        <div class="flex-1"><label class="text-xs font-bold text-gray-600 block mb-1">Select File</label><input type="file" name="videoFile" accept="video/mp4" class="w-full p-1 border rounded bg-white text-xs" required></div>
                                        <button type="submit" class="bg-blue-600 text-white px-4 py-2 rounded text-sm font-bold hover:bg-blue-700">Upload Answer</button>
                                    </form>
                                    <% } else { %>
                                        <div class="mt-2 p-3 bg-red-100 text-red-700 rounded text-sm font-bold border border-red-200 text-center">This task has expired. You can no longer upload videos for it.</div>
                                    <% } %>
                                </div>
                                <% } } } catch(Exception e) {} } if(!hasTasks) { %> <p class="text-gray-500 italic">No pending tasks!</p> <% } %>
                            </div>
                        </div>
                        <% } %>
                        
                        <% if (rId == 1 || rId == 3 || rId == 4) { %>
                        <div class="bg-white rounded-lg shadow-md border-t-4 border-yellow-500 overflow-hidden">
                            <div class="p-6 border-b bg-gray-50"><h3 class="text-xl font-bold text-gray-800">📋 Requested Task History</h3></div>
                            <div class="p-6">
                                <% if(groupedTaskHistory.isEmpty()) { %>
                                    <p class="text-gray-500 italic text-center py-4">No tasks requested yet.</p>
                                <% } else { %>
                                    <div class="space-y-4">
                                        <% for(Map.Entry<String, List<Map<String,String>>> entry : groupedTaskHistory.entrySet()) { 
                                            String rolePoster = entry.getKey();
                                            List<Map<String,String>> tasks = entry.getValue();
                                            String safeId = "taskGroup-" + Math.abs(rolePoster.hashCode());
                                        %>
                                        <details class="border rounded-lg bg-white overflow-hidden shadow-sm group">
                                            <% if (rId == 1 || (rId == 4 && isHod)) { %>
                                            <summary class="w-full text-left p-4 bg-gray-50 hover:bg-gray-100 flex justify-between items-center font-bold text-gray-800 border-b cursor-pointer list-none outline-none">
                                                <span>👤 <%= rolePoster %> (<%= tasks.size() %> Tasks)</span>
                                                <span class="text-yellow-600 font-bold group-open:rotate-180 transition-transform">▼</span>
                                            </summary>
                                            <% } %>
                                            
                                            <div class="overflow-x-auto <%= (rId == 1 || (rId == 4 && isHod)) ? "hidden group-open:block" : "block" %>">
                                                <table class="min-w-full text-sm text-left text-gray-500">
                                                    <thead class="text-xs text-gray-700 uppercase bg-gray-50 border-b">
                                                        <tr>
                                                            <th class="px-6 py-3">Task Description</th>
                                                            <th class="px-6 py-3">Expiry Date</th>
                                                            <th class="px-6 py-3 text-center">Status</th>
                                                            <th class="px-6 py-3 text-right">Actions</th>
                                                        </tr>
                                                    </thead>
                                                    <tbody>
                                                    <% for(Map<String,String> h : tasks) { 
                                                        boolean isActive = "Active".equals(h.get("status"));
                                                        String statusBadge = isActive ? "bg-green-100 text-green-800" : "bg-gray-200 text-gray-600";
                                                    %>
                                                    <tr class="bg-white border-b hover:bg-gray-50 transition">
                                                        <td class="px-6 py-4 font-medium text-gray-900"><%= h.get("desc") %></td>
                                                        <td class="px-6 py-4"><%= h.get("expiry") %></td>
                                                        <td class="px-6 py-4 text-center"><span class="<%= statusBadge %> px-3 py-1 rounded-full text-xs font-bold uppercase"><%= h.get("status") %></span></td>
                                                        <td class="px-6 py-4 flex justify-end gap-2">
                                                            <button type="button" onclick="openAudienceModal('<%= h.get("desc").replace("'", "\\'") %>', '<%= h.get("audience").replace("'", "\\'") %>')" class="px-3 py-1.5 bg-gray-100 text-gray-600 border border-gray-300 text-xs font-bold rounded hover:bg-gray-200" title="View Audience">👥 Info</button>
                                                            <form action="videoAction" method="post" onsubmit="return confirm('WARNING: Deleting this task will permanently delete all submitted videos associated with it. Continue?');">
                                                                <input type="hidden" name="id" value="<%= h.get("id") %>">
                                                                <input type="hidden" name="action" value="deleteRequest">
                                                                <input type="hidden" name="view" value="dashboard">
                                                                <button type="submit" class="bg-red-50 text-red-600 hover:bg-red-600 hover:text-white border border-red-200 hover:border-transparent px-3 py-1.5 rounded text-xs font-bold transition flex gap-1 items-center">
                                                                    <span>Delete</span><span>🗑️</span>
                                                                </button>
                                                            </form>
                                                        </td>
                                                    </tr>
                                                    <% } %>
                                                    </tbody>
                                                </table>
                                            </div>
                                        </details>
                                        <% } %>
                                    </div>
                                <% } %>
                            </div>
                        </div>
                        <% } %>

                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-gray-500">
                            <h2 class="text-xl font-bold text-gray-800 mb-4">📂 My Upload History</h2>
                            <% if(myUploads.isEmpty()) { %><p class="text-gray-500 italic">No uploads yet.</p><% } else { %>
                            <div class="overflow-x-auto"><table class="min-w-full text-sm text-left text-gray-500"><thead class="text-xs text-gray-700 uppercase bg-gray-50"><tr><th class="px-6 py-3">Title</th><th class="px-6 py-3">Requested By</th><th class="px-6 py-3">Status</th><th class="px-6 py-3">Action</th></tr></thead><tbody><% for(Map<String,String> v : myUploads) { String s = v.get("status"); String c = "bg-yellow-100 text-yellow-800"; if("approved".equalsIgnoreCase(s)) c = "bg-green-100 text-green-800"; else if("rejected".equalsIgnoreCase(s) || "deleted".equalsIgnoreCase(s)) c = "bg-red-100 text-red-800"; %><tr class="bg-white border-b"><td class="px-6 py-4 font-medium text-gray-900"><%= v.get("title") %></td><td class="px-6 py-4"><span class="bg-gray-100 text-gray-700 text-xs px-2 py-1 rounded border"><%= v.get("requested_by") %></span></td><td class="px-6 py-4"><span class="<%= c %> px-2 py-1 rounded text-xs font-bold uppercase"><%= s %></span></td><td class="px-6 py-4"><button onclick="playVideo('<%= v.get("filename") %>')" class="text-blue-600 hover:text-blue-800 font-bold text-lg" title="Watch Video">▶</button></td></tr><% } %></tbody></table></div><% } %>
                        </div>
                    </div>
                </div>
                
                <% if (rId == 1 || rId == 3 || rId == 4) { %><div id="section-approvals" class="hidden"><div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-red-500"><h2 class="text-2xl font-bold text-gray-800 mb-6">⚠️ Pending Approvals</h2><% if(pendingVideos.isEmpty()) { %><p class="text-gray-500">No pending videos.</p><% } else { %><div class="grid grid-cols-1 md:grid-cols-2 gap-6"><% for(Map<String,String> v : pendingVideos) { %><div class="border border-gray-300 rounded-lg p-4 bg-white shadow-sm flex flex-col"><div class="bg-black w-full h-40 flex items-center justify-center mb-3 rounded overflow-hidden"><video controls class="w-full h-full object-contain"><source src="uploaded_videos/<%= v.get("filename") %>" type="video/mp4"></video></div><h3 class="font-bold text-lg truncate"><%= v.get("title") %></h3><p class="text-sm text-gray-600 mb-4">By: <b><%= v.get("by") %></b> (Dept: <%= v.get("dept") %>)</p><div class="flex gap-2 mt-auto"><form action="videoAction" method="post" class="flex-1"><input type="hidden" name="id" value="<%= v.get("id") %>"><input type="hidden" name="action" value="approve"><input type="hidden" name="view" value="approvals"><button class="w-full bg-green-600 text-white py-2 rounded font-bold hover:bg-green-700">Approve ✅</button></form><form action="videoAction" method="post" class="flex-1"><input type="hidden" name="id" value="<%= v.get("id") %>"><input type="hidden" name="action" value="delete"><input type="hidden" name="view" value="approvals"><button class="w-full bg-red-600 text-white py-2 rounded font-bold hover:bg-red-700">Reject 🗑️</button></form></div></div><% } %></div><% } %></div></div><% } %>

                <% if (rId == 1 || rId == 3 || rId == 4) { %>
                <div id="section-push" class="hidden"><div class="max-w-6xl mx-auto">
                    <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-green-500">
                        <h2 class="text-2xl font-bold text-gray-800 mb-6">🚀 Push New Survey Form</h2>
                        <form action="addFeedback" method="post" class="flex flex-col md:flex-row gap-8" id="push-wrapper">
                        
                        <div class="w-full md:w-1/3 border-r pr-6 space-y-4">
                            <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">1. Depts</label><div class="border rounded bg-white p-2 h-20 overflow-y-auto text-sm">
                                <% if(!isRestricted) { %><div class="flex items-center mb-1"><input type="checkbox" name="target_dept" value="All" checked onchange="toggleAll('dept', true, 'push-wrapper')" class="mr-2"><label>All</label></div><% } %>
                                <% for(String d : visibleDepts) { %><div class="flex items-center"><input type="checkbox" name="target_dept" value="<%= d %>" <% if(isRestricted) out.print("checked onclick='return false;'"); else out.print("onchange=\"toggleAll('dept', false, 'push-wrapper')\""); %> class="mr-2"><label><%= d %></label></div><% } %>
                            </div></div>
                            <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">2. Years</label><div class="border rounded bg-white p-2 h-20 overflow-y-auto text-sm">
                                <% if(rId == 1 || rId == 4) { // Admin, Faculty get the 'All' option %>
                                    <div class="flex items-center mb-1">
                                        <input type="checkbox" name="target_year" value="All" <% if(rId == 1) out.print("checked"); %> onchange="toggleAll('year', true, 'push-wrapper')" class="mr-2">
                                        <label>All</label>
                                    </div>
                                <% } %>
                                <% for(String y : visibleYears) { %>
                                    <div class="flex items-center">
                                        <input type="checkbox" name="target_year" value="<%= y %>" 
                                            <% 
                                               if (rId == 3) { 
                                                   out.print("checked onclick='return false;'"); // Mentor is locked
                                               } else if (rId == 1) {
                                                   out.print("checked onchange=\"toggleAll('year', false, 'push-wrapper')\""); // Admin is checked by default
                                               } else {
                                                   out.print("onchange=\"toggleAll('year', false, 'push-wrapper')\""); // Faculty are unchecked and unlocked
                                               }
                                            %> class="mr-2"><label><%= y %></label>
                                    </div>
                                <% } %>
                            </div></div>
                            <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">3. Students</label><div class="flex items-center mb-2"><input type="checkbox" class="enable-specific-checkbox h-4 w-4 text-blue-600 rounded" onchange="updateStudentList('push-wrapper')"><label class="ml-2 text-sm text-blue-700 font-semibold cursor-pointer">Target Specific Students?</label></div><div class="student-list-wrapper hidden"><div class="student-checkbox-container border rounded bg-white p-2 h-32 overflow-y-auto text-sm"></div></div><input type="hidden" name="target_user_default" value="All"></div>
                        </div>
                        
                        <div class="w-full md:w-2/3 flex flex-col gap-4">
                            <div><label class="block text-gray-700 font-medium mb-2">Description / Survey Title</label><input type="text" name="description" class="w-full p-3 border rounded" required></div>
                            
                            <div>
                                <label class="block text-gray-700 font-medium mb-2">Survey Questions</label>
                                <div id="push-internal-group">
                                    <input type="hidden" name="questions" id="hidden_survey_questions" value="[]">
                                    
                                    <div id="form-builder-empty" class="border-2 border-dashed border-gray-300 p-8 text-center rounded bg-gray-50">
                                        <button type="button" onclick="openFormBuilder()" class="bg-gray-800 text-white px-6 py-2 rounded text-sm font-bold shadow hover:bg-gray-700 transition">➕ Create Form Fields</button>
                                    </div>
                                    
                                    <div id="form-builder-summary" class="hidden border border-gray-300 rounded p-4 bg-white shadow-sm">
                                        <div class="flex justify-between items-center mb-2">
                                            <h4 class="font-bold text-gray-800 text-lg">📝 Form <span id="summary-form-id" class="text-indigo-600">#Draft</span></h4>
                                            <div>
                                                <button type="button" onclick="toggleFormPreview()" class="text-gray-500 hover:text-gray-800 mr-3 text-sm font-bold">▼ View Fields</button>
                                                <button type="button" onclick="openFormBuilder()" class="text-indigo-600 hover:text-indigo-800 text-sm font-bold">✏️ Edit</button>
                                            </div>
                                        </div>
                                        <div id="form-builder-preview-list" class="hidden text-sm text-gray-600 border-t pt-2 mt-2 space-y-1">
                                            </div>
                                    </div>
                                </div>
                            </div>
                            
                            <div class="mt-auto flex justify-end"><button type="submit" class="bg-green-600 text-white px-8 py-3 rounded font-bold hover:bg-green-700 shadow-md">Push Survey 🚀</button></div>
                        </div>
                        
                    </form></div>
                </div></div>
                <% } %>

                <% if (rId == 1 || rId == 3 || rId == 4) { %>
                <div id="section-ask-video" class="hidden"><div class="max-w-6xl mx-auto"><div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-pink-500"><h2 class="text-2xl font-bold text-gray-800 mb-6">🎥 Ask Students for Video</h2><form action="addVideoRequest" method="post" class="flex flex-col md:flex-row gap-8" id="ask-wrapper">
                    <div class="w-full md:w-1/3 border-r pr-6 space-y-4">
                        <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">1. Depts</label><div class="border rounded bg-white p-2 h-20 overflow-y-auto text-sm">
                            <% if(!isRestricted) { %><div class="flex items-center mb-1"><input type="checkbox" name="target_dept" value="All" checked onchange="toggleAll('dept', true, 'ask-wrapper')" class="mr-2"><label>All</label></div><% } %>
                            <% for(String d : visibleDepts) { %><div class="flex items-center"><input type="checkbox" name="target_dept" value="<%= d %>" <% if(isRestricted) out.print("checked onclick='return false;'"); else out.print("onchange=\"toggleAll('dept', false, 'ask-wrapper')\""); %> class="mr-2"><label><%= d %></label></div><% } %>
                        </div></div>
                        <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">2. Years</label><div class="border rounded bg-white p-2 h-20 overflow-y-auto text-sm">
                            <% if(rId == 1 || rId == 4) { // Admin, Faculty get the 'All' option %>
                                <div class="flex items-center mb-1">
                                    <input type="checkbox" name="target_year" value="All" <% if(rId == 1) out.print("checked"); %> onchange="toggleAll('year', true, 'ask-wrapper')" class="mr-2">
                                    <label>All</label>
                                </div>
                            <% } %>
                            <% for(String y : visibleYears) { %>
                                <div class="flex items-center">
                                    <input type="checkbox" name="target_year" value="<%= y %>" 
                                        <% 
                                           if (rId == 3) { 
                                               out.print("checked onclick='return false;'"); // Mentor is locked
                                           } else if (rId == 1) {
                                               out.print("checked onchange=\"toggleAll('year', false, 'ask-wrapper')\""); // Admin is checked by default
                                           } else {
                                               out.print("onchange=\"toggleAll('year', false, 'ask-wrapper')\""); // Faculty are unchecked and unlocked
                                           }
                                        %> class="mr-2"><label><%= y %></label>
                                </div>
                            <% } %>
                        </div></div>
                        <div><label class="block text-gray-700 font-bold mb-1 text-sm uppercase">3. Students</label><div class="flex items-center mb-2"><input type="checkbox" class="enable-specific-checkbox h-4 w-4 text-blue-600 rounded" onchange="updateStudentList('ask-wrapper')"><label class="ml-2 text-sm text-blue-700 font-semibold cursor-pointer">Target Specific Students?</label></div><div class="student-list-wrapper hidden"><div class="student-checkbox-container border rounded bg-white p-2 h-32 overflow-y-auto text-sm"></div></div><input type="hidden" name="target_user_default" value="All"></div>
                    </div>
                    
                    <div class="w-full md:w-2/3 flex flex-col gap-6">
                        <div class="flex gap-4 flex-col md:flex-row">
                            <div class="flex-1">
                                <label class="block text-gray-700 font-bold mb-2">Request Description</label>
                                <input type="text" name="description" class="w-full p-3 border border-gray-300 rounded focus:ring-2 focus:ring-pink-500 outline-none" required placeholder="e.g. Submitting OS Assignment">
                            </div>
                            <div class="flex-1">
                                <label class="block text-gray-700 font-bold mb-2">Expiry Date & Time</label>
                                <input type="datetime-local" name="expiry_date" class="w-full p-3 border border-gray-300 rounded focus:ring-2 focus:ring-pink-500 outline-none" required>
                            </div>
                        </div>
                        <div class="mt-auto flex justify-end"><button type="submit" class="bg-pink-600 text-white px-8 py-3 rounded font-bold hover:bg-pink-700 shadow-md transition">Push Request 🎥</button></div>
                    </div>
                </form></div></div></div>
                <% } %>
                
                <% if(rId == 1) { %>
                <div id="section-uploads" class="hidden">
                    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                        <div class="bg-white p-6 rounded-lg shadow-md border-t-4 border-orange-500">
                            <h3 class="font-bold text-lg mb-2">📄 Upload Students</h3>
                            <form action="uploadData" method="post" enctype="multipart/form-data">
                                <input type="hidden" name="dataType" value="student">
                                <input type="file" name="excelFile" accept=".xlsx" class="mb-4 text-xs w-full" required>
                                <button class="w-full bg-orange-600 text-white py-2 rounded font-bold hover:bg-orange-700">Upload Students</button>
                            </form>
                        </div>
                        
                        <div class="bg-white p-6 rounded-lg shadow-md border-t-4 border-purple-500">
                            <h3 class="font-bold text-lg mb-2">👨‍🏫 Upload Faculty</h3>
                            <form action="uploadData" method="post" enctype="multipart/form-data">
                                <input type="hidden" name="dataType" value="faculty">
                                <input type="file" name="excelFile" accept=".xlsx" class="mb-4 text-xs w-full" required>
                                <button class="w-full bg-purple-600 text-white py-2 rounded font-bold hover:bg-purple-700">Upload Faculty</button>
                            </form>
                        </div>
                        
                        <div class="bg-white p-6 rounded-lg shadow-md border-t-4 border-red-500">
                            <h3 class="font-bold text-lg mb-2">🛡️ Upload Admins</h3>
                            <form action="uploadData" method="post" enctype="multipart/form-data">
                                <input type="hidden" name="dataType" value="admin">
                                <input type="file" name="excelFile" accept=".xlsx" class="mb-4 text-xs w-full" required>
                                <button class="w-full bg-red-600 text-white py-2 rounded font-bold hover:bg-red-700">Upload Admins</button>
                            </form>
                        </div>
                        
                        <div class="bg-white p-6 rounded-lg shadow-md border-t-4 border-blue-500">
                            <h3 class="font-bold text-lg mb-2">🎓 Upload Alumni</h3>
                            <form action="uploadData" method="post" enctype="multipart/form-data">
                                <input type="hidden" name="dataType" value="alumni">
                                <input type="file" name="excelFile" accept=".xlsx" class="mb-4 text-xs w-full" required>
                                <button class="w-full bg-blue-600 text-white py-2 rounded font-bold hover:bg-blue-700">Upload Alumni</button>
                            </form>
                        </div>
                    </div>
                </div>
                
                <div id="section-add-student" class="hidden">
                    <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-blue-600 max-w-lg mx-auto">
                        <h2 class="text-2xl font-bold text-gray-800 mb-6">➕ Add Single User</h2>
                        <form action="addStudent" method="post" class="space-y-4">
                            <div class="mb-4">
                                <label class="block text-sm font-medium text-gray-700 mb-1">Role <span class="text-red-500">*</span></label>
                                <select id="add_role_id" name="role_id" class="w-full p-2 border rounded bg-white" onchange="handleAddUserRoleChange()" required>
                                    <option value="" disabled selected>Select Role</option>
                                    <option value="1">Admin</option>
                                    <option value="4">Faculty</option>
                                    <option value="2">Student</option>
                                    <option value="5">Alumni</option>
                                </select>
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700">Full Name</label>
                                <input type="text" name="name" class="w-full p-2 border rounded" required>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Roll Number/ID</label>
                                <input type="text" name="roll_number" class="w-full p-2 border rounded">
                            </div>
                            
                            <div class="grid grid-cols-2 gap-4">
                                <div id="add_dept_container">
                                    <label class="block text-sm font-medium text-gray-700">Department</label>
                                    <select id="add_department" name="department" class="w-full p-2 border rounded bg-white" required>
                                        <option value="" disabled selected>Select</option>
                                        <option value="CSE">CSE</option>
                                        <option value="IT">IT</option>
                                        <option value="CIVIL">CIVIL</option>
                                        <option value="MECHANICAL">MECHANICAL</option>
                                        <option value="ELECTRICAL">ELECTRICAL</option>
                                        <option value="ECE">ECE</option>
                                        <option value="CYBER SECURITY">CYBER SECURITY</option>
                                    </select>
                                </div>
                                <div id="add_year_container">
                                    <label class="block text-sm font-medium text-gray-700">Year</label>
                                    <select id="add_year" name="year" class="w-full p-2 border rounded bg-white" required>
                                        <option value="" disabled selected>Select</option>
                                        <option value="1st">1st</option>
                                        <option value="2nd">2nd</option>
                                        <option value="3rd">3rd</option>
                                        <option value="4th">4th</option>
                                    </select>
                                </div>
                            </div>
                            
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Username (UID)</label>
                                <input type="text" name="username" class="w-full p-2 border rounded" required>
                            </div>
                            <div>
                                <label class="block text-sm font-medium text-gray-700">Temporary Password</label>
                                <input type="password" name="password" class="w-full p-2 border rounded" required>
                            </div>
                            
                            <button type="submit" class="w-full bg-blue-600 text-white py-2 rounded font-bold hover:bg-blue-700">Create Account</button>
                        </form>
                    </div>
                </div>
                
                <div id="section-password-reset" class="hidden bg-white p-8 rounded-lg shadow-md border-t-4 border-gray-800 max-w-4xl mx-auto"><h2 class="text-2xl font-bold mb-6">🔑 Admin Password Reset</h2><div class="relative"><input type="text" id="search-input" placeholder="Start typing name (min 2 chars)..." onkeyup="fetchUserSuggestions(this.value)" class="w-full p-3 border rounded text-lg focus:outline-none focus:ring-2 focus:ring-blue-500" autocomplete="off"><div id="search-suggestions" class="hidden absolute w-full bg-white border border-gray-200 mt-1 rounded shadow-lg max-h-60 overflow-y-auto z-50"></div></div><form id="search-form" action="AdminUserAction" method="post" class="mt-4 flex justify-end"><input type="hidden" name="action" value="search"><input type="hidden" name="searchQuery" id="hidden-search-query"><button type="submit" onclick="document.getElementById('hidden-search-query').value=document.getElementById('search-input').value" class="bg-blue-600 text-white px-6 py-2 rounded font-bold hover:bg-blue-700">Search User</button></form>
                <% if (searchResults != null) { %>
                <div class="mt-8">
                    <div class="flex justify-between items-center mb-4"><h3 class="text-xl font-bold">Search Results</h3><button onclick="window.location.href='home.jsp'" class="text-red-500 text-sm font-bold">Clear X</button></div>
                    <% if (searchResults.isEmpty()) { %><p class="text-gray-500">No users found.</p><% } else { %><div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4"><% for(Map<String,String> u : searchResults) { %><div onclick="openAdminResetModal('<%= u.get("uid") %>')" class="p-4 border rounded hover:bg-blue-50 cursor-pointer transition"><h4 class="font-bold text-lg"><%= u.get("name") %></h4><p class="text-sm text-gray-600">ID: <%= u.get("uid") %></p><p class="text-xs text-gray-500">Role: <%= u.get("role") %> | Dept: <%= u.get("dept") %></p><p class="text-blue-600 text-xs font-bold mt-2 text-right">Click to Reset Password</p></div><% } %></div><% } %>
                </div>
                <% } %>
                </div>
                
                <div id="section-assign-hod" class="hidden bg-white p-8 rounded-lg shadow-md border-t-4 border-yellow-500 max-w-lg mx-auto">
                    <h2 class="text-2xl font-bold mb-2">👑 Appoint Head of Department</h2>
                    <p class="text-gray-600 text-sm mb-6">Enter a Faculty UID. The system will automatically detect their department and grant them exclusive HOD privileges.</p>
                    <form action="assignHod" method="post">
                        <div class="mb-6 relative">
                            <label class="block text-sm font-medium text-gray-700 mb-1">Faculty Username (UID)</label>
                            
                            <input type="text" id="hod_faculty_uid" name="faculty_uid" placeholder="Start typing name or UID..." onkeyup="showHodHints(this.value)" autocomplete="off" class="w-full p-3 border rounded text-lg focus:outline-none focus:ring-2 focus:ring-yellow-500" required>
                            
                            <div id="hod-hints" class="hidden absolute w-full bg-white border border-gray-200 mt-1 rounded shadow-xl max-h-48 overflow-y-auto z-50"></div>
                        </div>
                        
                        <button type="submit" class="w-full bg-yellow-600 text-white py-3 rounded font-bold hover:bg-yellow-700 shadow-md">Make HOD</button>
                    </form>
                </div>
                <% } %>
                
                <% if (rId == 4 && isHod) { %>
                <div id="section-assign-mentor" class="hidden">
                    <div class="max-w-4xl mx-auto">
                        <div class="flex justify-between items-center mb-6">
                            <h2 class="text-2xl font-bold text-gray-800">👥 Assign Mentors</h2>
                            <% if(!assignedMap.isEmpty()) { %>
                                <button onclick="document.getElementById('edit-modal-selector').classList.remove('hidden')" class="bg-gray-200 hover:bg-gray-300 text-gray-700 px-4 py-2 rounded text-sm font-bold flex items-center"><span>✏️ Edit Assignments</span></button>
                            <% } %>
                        </div>
                        <div class="bg-white p-8 rounded-lg shadow-md border-t-4 border-indigo-600">
                            <form action="AssignMentorServlet" method="post">
                                <input type="hidden" name="action" value="assign">
                                <div class="mb-6">
                                    <label class="block text-gray-700 font-bold mb-2">1. Select Mentor</label>
                                    <select name="mentor_uid" class="w-full p-3 border rounded bg-gray-50" required>
                                        <option value="">-- Choose a Mentor --</option>
                                        <% for(Map<String,String> m : availableMentors) { %>
                                            <option value="<%= m.get("uid") %>"><%= m.get("name") %> (<%= m.get("uid") %>)</option>
                                        <% } %>
                                    </select>
                                    <% if(availableMentors.isEmpty()) { %><p class="text-xs text-red-500 mt-1">No mentors found in your Dept/Year.</p><% } %>
                                </div>
                                
                                <div class="mb-6">
                                    <label class="block text-gray-700 font-bold mb-2">2. Filter Students by Year</label>
                                    <div class="flex gap-4 p-3 border rounded bg-gray-50">
                                        <label class="flex items-center"><input type="checkbox" value="1st" class="mentor-year-filter w-4 h-4 mr-2" checked onchange="renderUnassignedStudents()"> 1st</label>
                                        <label class="flex items-center"><input type="checkbox" value="2nd" class="mentor-year-filter w-4 h-4 mr-2" checked onchange="renderUnassignedStudents()"> 2nd</label>
                                        <label class="flex items-center"><input type="checkbox" value="3rd" class="mentor-year-filter w-4 h-4 mr-2" checked onchange="renderUnassignedStudents()"> 3rd</label>
                                        <label class="flex items-center"><input type="checkbox" value="4th" class="mentor-year-filter w-4 h-4 mr-2" checked onchange="renderUnassignedStudents()"> 4th</label>
                                    </div>
                                </div>

                                <div class="mb-6">
                                    <label class="block text-gray-700 font-bold mb-2">3. Select Unassigned Students</label>
                                    <div id="unassigned_container" class="border rounded bg-white p-3 h-64 overflow-y-auto">
                                        </div>
                                </div>
                                <div class="flex justify-end"><button type="submit" class="bg-indigo-600 text-white px-8 py-3 rounded font-bold hover:bg-indigo-700 shadow-lg transition">Assign Selected Students ✅</button></div>
                            </form>
                        </div>
                    </div>
                </div>
                
                <div id="edit-modal-selector" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"><div class="bg-white rounded-lg w-full max-w-md p-6 relative shadow-2xl"><button onclick="document.getElementById('edit-modal-selector').classList.add('hidden')" class="absolute top-4 right-4 text-gray-500 hover:text-gray-800 text-2xl">&times;</button><h3 class="text-xl font-bold mb-4">Select Mentor to Edit</h3><div class="space-y-2 max-h-96 overflow-y-auto"><% for(String mName : assignedMap.keySet()) { %><button onclick="openEditModal('list-<%= mName.hashCode() %>', '<%= mName %>'); document.getElementById('edit-modal-selector').classList.add('hidden');" class="w-full text-left p-3 border rounded hover:bg-indigo-50 font-medium text-gray-700 flex justify-between"><span><%= mName %></span><span class="bg-indigo-100 text-indigo-800 text-xs px-2 py-1 rounded-full"><%= assignedMap.get(mName).size() %> students</span></button><% } %></div></div></div>
                <div id="edit-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"><div class="bg-white rounded-lg w-full max-w-lg p-6 relative shadow-2xl"><button onclick="closeEditModal()" class="absolute top-4 right-4 text-gray-500 hover:text-gray-800 text-2xl">&times;</button><h3 class="text-xl font-bold mb-1">Unassign Students</h3><p class="text-sm text-gray-500 mb-4">Mentor: <span id="modal-mentor-name" class="font-bold text-indigo-600"></span></p><form action="AssignMentorServlet" method="post"><input type="hidden" name="action" value="unassign"><% for(Map.Entry<String, List<Map<String,String>>> entry : assignedMap.entrySet()) { %><div id="list-<%= entry.getKey().hashCode() %>" class="edit-list hidden border rounded p-3 h-64 overflow-y-auto bg-gray-50"><% for(Map<String,String> s : entry.getValue()) { %><div class="flex items-center mb-2 p-2 bg-white rounded border"><input type="checkbox" name="student_uids" value="<%= s.get("uid") %>" class="mr-3 h-5 w-5 text-red-500"><div><p class="font-semibold text-gray-800 text-sm"><%= s.get("name") %> (<%= s.get("uid") %>)</p></div></div><% } %></div><% } %><div class="mt-6 flex justify-end"><button type="button" onclick="closeEditModal()" class="mr-3 px-4 py-2 text-gray-600 hover:bg-gray-100 rounded font-bold">Cancel</button><button type="submit" class="bg-red-600 text-white px-6 py-2 rounded font-bold hover:bg-red-700">Remove Selected 🗑️</button></div></form></div></div>
                <% } %>

            </div>
        </div>
    </div>

    <div id="take-survey-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg w-full max-w-2xl p-6 relative shadow-2xl flex flex-col max-h-[90vh]">
            <button onclick="closeTakeSurveyModal()" class="absolute top-4 right-4 text-gray-500 hover:text-gray-800 text-2xl">&times;</button>
            <h3 class="text-2xl font-bold mb-2 text-indigo-600" id="take-survey-title">Survey Form</h3>
            <p class="text-sm text-gray-500 mb-4 pb-4 border-b">Please rate the following fields from 1 (Lowest) to 5 (Highest).</p>
            
            <form id="take-survey-form" onsubmit="submitSurveyAnswers(event)" class="overflow-y-auto flex-1 pr-2">
                <input type="hidden" id="take_survey_id" name="survey_id">
                
                <div id="take-survey-questions-container" class="space-y-4"></div>
                
                <div class="mt-6 pt-4 border-t flex justify-end">
                    <button type="submit" class="bg-indigo-600 text-white px-8 py-3 rounded font-bold hover:bg-indigo-700 shadow-md">Submit Ratings ✅</button>
                </div>
            </form>
        </div>
    </div>

    <div id="form-builder-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
        <div class="bg-white rounded-lg w-full max-w-lg p-6 relative shadow-2xl flex flex-col max-h-[90vh]">
            <div class="flex justify-between items-center mb-4">
                <h3 class="text-xl font-bold text-gray-800">🛠️ Form Builder <span class="text-gray-400 text-sm ml-2 font-normal">#Draft</span></h3>
                <button type="button" onclick="closeFormBuilder()" class="text-gray-500 hover:text-gray-800 text-2xl">&times;</button>
            </div>
            
            <div class="flex-1 overflow-y-auto mb-4 border border-gray-200 rounded p-3 bg-gray-50 min-h-[200px]" id="builder-fields-list">
                <p class="text-sm text-gray-400 italic text-center mt-10">No fields added yet.</p>
            </div>

            <div class="border-t pt-4">
                <label class="block text-xs font-bold text-gray-700 uppercase mb-1">New Rating Field</label>
                <div class="flex gap-2">
                    <input type="text" id="new_field_input" placeholder="e.g., Course Content Quality" class="flex-1 p-2 border rounded text-sm focus:ring-2 focus:ring-indigo-500 outline-none" onkeypress="if(event.key === 'Enter'){ event.preventDefault(); addFormField(); }">
                    <button type="button" onclick="addFormField()" class="bg-indigo-600 text-white px-4 py-2 rounded text-sm font-bold hover:bg-indigo-700">Add</button>
                </div>
            </div>

            <div class="mt-6 flex justify-end">
                <button type="button" onclick="saveFormBuilder()" class="bg-green-600 text-white px-6 py-2 rounded font-bold hover:bg-green-700 shadow">Save Form 💾</button>
            </div>
        </div>
    </div>
    
    <div id="audience-modal" class="hidden fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-[60]">
        <div class="bg-white rounded-xl w-full max-w-md p-6 relative shadow-2xl flex flex-col">
            <button onclick="closeAudienceModal()" class="absolute top-4 right-4 text-gray-400 hover:text-gray-800 text-3xl font-bold">&times;</button>
            <h3 class="text-xl font-bold mb-4 text-gray-800 border-b pb-2" id="audience-modal-title">Audience Info</h3>
            <div class="p-4 bg-gray-50 rounded border text-sm font-mono text-gray-700 break-words" id="audience-modal-content"></div>
            <div class="mt-6 pt-4 border-t flex justify-end">
                <button type="button" onclick="closeAudienceModal()" class="bg-indigo-600 text-white px-6 py-2 rounded font-bold hover:bg-indigo-700">Close</button>
            </div>
        </div>
    </div>

    <div id="floating-video-player" class="hidden fixed bottom-6 right-6 z-[100] bg-black rounded-lg shadow-2xl overflow-hidden flex-col w-80 md:w-96 border-4 border-gray-800">
        <div class="bg-gray-900 text-white p-2 flex justify-between items-center cursor-move">
            <span class="text-xs font-bold uppercase tracking-wider">Now Playing</span>
            <button onclick="closeVideo()" class="text-gray-400 hover:text-white font-bold">&times;</button>
        </div>
        <video id="floating-video-src" controls class="w-full aspect-video bg-black"></video>
    </div>

    <div id="analysis-modal" class="hidden fixed inset-0 bg-black bg-opacity-60 flex items-center justify-center z-[60]">
        <div class="bg-white rounded-xl w-full max-w-2xl p-6 relative shadow-2xl flex flex-col max-h-[90vh]">
            <button onclick="closeAnalysisModal()" class="absolute top-4 right-4 text-gray-400 hover:text-gray-800 text-3xl font-bold">&times;</button>
            <h3 class="text-2xl font-bold mb-1 text-gray-800" id="analysis-title">Survey Analytics</h3>
            <p class="text-sm text-gray-500 mb-6 border-b pb-4">Average ratings based on student responses.</p>
            <div class="flex items-center justify-center mb-8 bg-indigo-50 p-6 rounded-lg border border-indigo-100">
                <div class="text-center">
                    <p class="text-sm font-bold text-indigo-400 uppercase tracking-widest mb-1">Overall Average Score</p>
                    <div class="text-6xl font-black text-indigo-600 flex items-baseline justify-center gap-2">
                        <span id="analysis-overall-score">0.0</span> <span class="text-2xl text-indigo-300">/ 5.0</span>
                    </div>
                </div>
            </div>
            <div class="flex-1 overflow-y-auto pr-2">
                <h4 class="font-bold text-gray-800 mb-4 uppercase text-sm tracking-wider">Question Breakdown</h4>
                <div id="analysis-breakdown" class="space-y-4"></div>
            </div>
            <div class="mt-6 pt-4 border-t flex justify-end">
                <button type="button" onclick="closeAnalysisModal()" class="bg-gray-200 text-gray-800 px-6 py-2 rounded font-bold hover:bg-gray-300">Close</button>
            </div>
        </div>
    </div>

    <div id="password-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"><div class="bg-white rounded-lg w-full max-w-sm p-6 relative shadow-2xl"><button onclick="closePassModal()" class="absolute top-4 right-4 text-gray-500 hover:text-gray-800 text-2xl">&times;</button><h3 class="text-xl font-bold mb-4">Change Password</h3><form action="ChangePasswordServlet" method="post"><div class="mb-4"><label class="block text-sm font-medium text-gray-700 mb-1">Current Password</label><input type="password" name="currentPass" class="w-full p-2 border rounded" required></div><div class="mb-4"><label class="block text-sm font-medium text-gray-700 mb-1">New Password</label><input type="password" name="newPass" class="w-full p-2 border rounded" required></div><div class="mb-6"><label class="block text-sm font-medium text-gray-700 mb-1">Confirm New Password</label><input type="password" name="confirmPass" class="w-full p-2 border rounded" required></div><button type="submit" class="w-full bg-blue-600 text-white py-2 rounded font-bold hover:bg-blue-700">Save</button></form></div></div>
    <div id="admin-reset-modal" class="hidden fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50"><div class="bg-white rounded-lg w-full max-w-sm p-6 relative shadow-2xl"><button onclick="closeAdminResetModal()" class="absolute top-4 right-4 text-gray-500 hover:text-gray-800 text-2xl">&times;</button><h3 class="text-xl font-bold mb-2">Reset Password</h3><p class="text-sm text-gray-500 mb-4">For User: <span id="reset-username-display" class="font-bold text-red-600"></span></p><form action="AdminUserAction" method="post"><input type="hidden" name="action" value="resetPass"><input type="hidden" name="targetUser" id="target-user-input"><div class="mb-4"><label class="block text-sm font-medium text-gray-700 mb-1">New Password</label><input type="password" name="newPass" class="w-full p-2 border rounded" required></div><div class="mb-6"><label class="block text-sm font-medium text-gray-700 mb-1">Confirm Password</label><input type="password" name="confirmPass" class="w-full p-2 border rounded" required></div><button type="submit" class="w-full bg-red-600 text-white py-2 rounded font-bold hover:bg-red-700">Reset Password</button></form></div></div>

</body>
</html>