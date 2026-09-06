<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<%@ page import="java.util.*" %>
<%@ page import="com.example.login.Video" %>
<%
    if (session.getAttribute("userName") == null) {
        response.sendRedirect("login.html");
        return;
    }
    
    Object roleObj = session.getAttribute("roleId");
    int rId = (roleObj != null) ? (Integer) roleObj : 0;
    boolean isHod = session.getAttribute("isHod") != null ? (Boolean) session.getAttribute("isHod") : false;
    
    Map<String, List<Video>> groupedVideos = (Map<String, List<Video>>) request.getAttribute("groupedVideos");
%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Video Gallery</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <script>
        function playVideo(filename, title) {
            const playerDiv = document.getElementById('video-modal');
            const videoElement = document.getElementById('main-video-player');
            document.getElementById('modal-video-title').innerText = title;
            videoElement.src = 'uploaded_videos/' + filename;
            playerDiv.classList.remove('hidden');
            playerDiv.classList.add('flex');
            videoElement.play().catch(e => console.error("Autoplay blocked:", e));
        }

        function closeVideo() {
            const playerDiv = document.getElementById('video-modal');
            const videoElement = document.getElementById('main-video-player');
            videoElement.pause();
            videoElement.src = "";
            playerDiv.classList.add('hidden');
            playerDiv.classList.remove('flex');
        }

        function toggleGroup(groupId) {
            const groupContent = document.getElementById(groupId);
            const icon = document.getElementById('icon-' + groupId);
            if (groupContent.classList.contains('hidden')) {
                groupContent.classList.remove('hidden');
                icon.innerText = "▲";
            } else {
                groupContent.classList.add('hidden');
                icon.innerText = "▼";
            }
        }
    </script>
</head>
<body class="bg-gray-100 min-h-screen">

    <nav class="bg-gray-900 text-white p-4 shadow-lg sticky top-0 z-50">
        <div class="max-w-7xl mx-auto flex justify-between items-center">
            <h1 class="text-xl font-bold flex items-center"><span class="mr-2">📺</span> Video Gallery</h1>
            <a href="home.jsp" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded text-sm font-bold transition shadow">← Back to Dashboard</a>
        </div>
    </nav>

    <div class="max-w-7xl mx-auto p-8">
        
        <div class="flex justify-between items-end border-b pb-2 mb-6">
            <div>
                <h2 class="text-3xl font-bold text-gray-800">Video Gallery</h2>
                <p class="text-gray-500 mt-1">View approved lectures and video assignments.</p>
            </div>
            <% if (rId == 1 || rId == 3 || rId == 4 || rId == 5) { %>
                <span class="text-xs text-red-600 font-semibold bg-red-50 px-3 py-1.5 rounded border border-red-200">Staff Mode: Management privileges active</span>
            <% } %>
        </div>

        <%-- VIDEO GALLERY GROUPS --%>
        <% if(groupedVideos == null || groupedVideos.isEmpty()) { %>
            <div class="bg-white p-16 text-center rounded-lg shadow-sm border border-gray-200">
                <span class="text-6xl mb-4 block">📭</span>
                <h2 class="text-2xl font-bold text-gray-700">No Videos Available</h2>
                <p class="text-gray-500 mt-2">There are currently no approved videos available for your view.</p>
            </div>
        <% } else { %>
            <div class="space-y-6">
                <% 
                int groupIndex = 0;
                for (Map.Entry<String, List<Video>> entry : groupedVideos.entrySet()) { 
                    String groupName = entry.getKey();
                    List<Video> videos = entry.getValue();
                    String groupId = "group-" + groupIndex++;
                    boolean isGeneral = groupName.startsWith("Lectures by:");
                %>
                
                <div class="bg-white rounded-lg shadow-sm border border-gray-300 overflow-hidden">
                    <button onclick="toggleGroup('<%= groupId %>')" class="w-full bg-gray-50 hover:bg-indigo-50 p-4 flex justify-between items-center border-b border-gray-200 transition">
                        <div class="flex items-center gap-3">
                            <span class="text-2xl"><%= isGeneral ? "🏫" : "👤" %></span>
                            <h2 class="text-xl font-bold text-gray-800"><%= groupName %></h2>
                            <span class="bg-indigo-100 text-indigo-800 text-xs px-3 py-1 rounded-full font-bold ml-2"><%= videos.size() %> Videos</span>
                        </div>
                        <span id="icon-<%= groupId %>" class="text-gray-500 font-bold"><%= isGeneral ? "▲" : "▼" %></span>
                    </button>
                    
                    <div id="<%= groupId %>" class="p-6 bg-white <%= isGeneral ? "" : "hidden" %>">
                        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
                            <% for (Video v : videos) { %>
                                <div class="border border-gray-200 rounded-lg overflow-hidden shadow-sm hover:shadow-xl transition bg-white flex flex-col group relative">
                                    <div class="bg-black aspect-video relative flex items-center justify-center cursor-pointer" onclick="playVideo('<%= v.getFileName() %>', '<%= v.getTitle().replace("'", "\\'") %>')">
                                        <video class="w-full h-full object-cover opacity-70 group-hover:opacity-100 transition" preload="metadata">
                                            <source src="uploaded_videos/<%= v.getFileName() %>#t=1" type="video/mp4">
                                        </video>
                                        <div class="absolute inset-0 flex items-center justify-center pointer-events-none">
                                            <div class="w-12 h-12 bg-white bg-opacity-90 rounded-full flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform">
                                                <span class="text-indigo-600 text-xl ml-1">▶</span>
                                            </div>
                                        </div>
                                    </div>
                                    
                                    <div class="p-4 flex-1 flex flex-col">
                                        <h3 class="font-bold text-gray-800 mb-2 leading-tight line-clamp-2"><%= v.getTitle() %></h3>
                                        <div class="space-y-1 mb-4">
                                            <p class="text-xs font-semibold uppercase tracking-wider text-gray-500">Dept: <span class="text-indigo-600"><%= v.getDepartment() %></span></p>
                                            <% if(!isGeneral) { %><p class="text-xs text-gray-600">By Student: <b><%= v.getUploadedBy() %></b></p><% } %>
                                            <p class="text-xs text-gray-400 mt-1">Uploaded: <%= v.getUploadedAt() %></p>
                                        </div>
                                        
                                        <% if (rId == 1 || rId == 3 || rId == 4) { %>
                                        <div class="mt-auto border-t pt-3 flex justify-end">
                                            <form action="videoAction" method="post" onsubmit="return confirm('Are you sure you want to remove this video?');">
                                                <input type="hidden" name="id" value="<%= v.getId() %>">
                                                <input type="hidden" name="action" value="delete">
                                                <input type="hidden" name="view" value="gallery">
                                                <button type="submit" class="flex items-center gap-1 bg-red-50 text-red-600 hover:bg-red-600 hover:text-white border border-red-200 px-3 py-1.5 rounded text-xs font-bold transition">
                                                    <span>Delete Video</span><span>🗑️</span>
                                                </button>
                                            </form>
                                        </div>
                                        <% } %>
                                    </div>
                                </div>
                            <% } %>
                        </div>
                    </div>
                </div>
                <% } %>
            </div>
        <% } %>
    </div>

    <div id="video-modal" class="hidden fixed inset-0 bg-black bg-opacity-90 z-50 flex items-center justify-center p-4">
        <div class="w-full max-w-5xl bg-gray-900 rounded-xl overflow-hidden shadow-2xl border border-gray-700">
            <div class="p-4 flex justify-between items-center bg-black border-b border-gray-800">
                <h3 id="modal-video-title" class="text-white font-bold text-lg truncate pr-4">Video Title</h3>
                <button onclick="closeVideo()" class="text-gray-400 hover:text-white text-3xl font-bold transition">&times;</button>
            </div>
            <div class="aspect-video w-full bg-black">
                <video id="main-video-player" controls class="w-full h-full" controlsList="nodownload"></video>
            </div>
        </div>
    </div>

</body>
</html>