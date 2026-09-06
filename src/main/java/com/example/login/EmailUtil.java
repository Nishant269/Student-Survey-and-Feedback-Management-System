package com.example.login;

import java.util.Properties;
import jakarta.mail.Authenticator;
import jakarta.mail.Message;
import jakarta.mail.PasswordAuthentication;
import jakarta.mail.Session;
import jakarta.mail.Transport;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeMessage;

public class EmailUtil {
    
    // It is perfectly safe to leave your email address visible in the code
    private static final String SENDER_EMAIL = "sksamimjulislam@gmail.com";
    
    // Securely fetches the 16-character App Password from your PC's Environment Variables
    private static final String SENDER_PASSWORD = System.getenv("GMAIL_APP_PASSWORD"); 

    public static boolean sendOtpEmail(String recipientEmail, String otp) {
        
        // Safety check: Alerts you if the environment variable is missing on your local PC or Render
        if (SENDER_PASSWORD == null || SENDER_PASSWORD.trim().isEmpty()) {
            System.err.println("CRITICAL ERROR: GMAIL_APP_PASSWORD environment variable is not set!");
            return false;
        }

        Properties props = new Properties();
        props.put("mail.smtp.auth", "true");
        props.put("mail.smtp.starttls.enable", "true");
        props.put("mail.smtp.host", "smtp.gmail.com");
        props.put("mail.smtp.port", "587");

        Session session = Session.getInstance(props, new Authenticator() {
            @Override
            protected PasswordAuthentication getPasswordAuthentication() {
                return new PasswordAuthentication(SENDER_EMAIL, SENDER_PASSWORD);
            }
        });

        try {
            Message message = new MimeMessage(session);
            message.setFrom(new InternetAddress(SENDER_EMAIL));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(recipientEmail));
            message.setSubject("Your Registration OTP");
            
            String htmlContent = "<div style='font-family: Arial; padding: 20px; text-align: center;'>"
                    + "<h2 style='color: #2563EB;'>Account Verification</h2>"
                    + "<p>Here is your One-Time Password (OTP) to complete your registration:</p>"
                    + "<h1 style='background: #F3F4F6; padding: 10px; display: inline-block; letter-spacing: 5px; color: #111827;'>" + otp + "</h1>"
                    + "<p style='color: #6B7280; font-size: 12px;'>This code is valid for your current session.</p>"
                    + "</div>";
            
            message.setContent(htmlContent, "text/html; charset=utf-8");
            Transport.send(message);
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            return false;
        }
    }
}