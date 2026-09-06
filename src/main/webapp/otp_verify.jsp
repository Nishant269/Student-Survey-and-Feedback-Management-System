<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verify OTP</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center min-h-screen py-10">
    <div class="bg-white p-8 rounded-lg shadow-md w-full max-w-sm text-center">
        <h1 class="text-2xl font-bold mb-2 text-gray-700">Check Your Email</h1>
        <p class="text-gray-500 text-sm mb-6">We've sent a 6-digit code to <b><%= request.getParameter("email") %></b></p>
        
        <% if(request.getParameter("error") != null) { %>
            <p class="text-red-500 text-sm font-bold mb-4">Invalid OTP. Please try again.</p>
        <% } %>

        <form action="verifyOtp" method="post">
            <div class="mb-6">
                <input type="text" name="userOtp" placeholder="Enter 6-digit OTP" class="w-full px-3 py-3 border border-gray-300 rounded-md text-center text-xl font-bold tracking-widest" required maxlength="6">
            </div>
            <button type="submit" class="w-full bg-blue-500 text-white py-2 rounded-md hover:bg-blue-600 font-bold transition">Verify & Register</button>
        </form>
    </div>
</body>
</html>