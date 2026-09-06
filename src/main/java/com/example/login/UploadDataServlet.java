package com.example.login;

import java.io.IOException;
import java.io.InputStream;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.MultipartConfig;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.Part;

import org.apache.poi.ss.usermodel.*;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

@WebServlet("/uploadData")
@MultipartConfig
public class UploadDataServlet extends HttpServlet {
    private static final long serialVersionUID = 1L;

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        
        String dataType = request.getParameter("dataType");
        Part filePart = request.getPart("excelFile");
        
        if (filePart == null || filePart.getSize() == 0) {
             response.sendRedirect("home.jsp");
             return;
        }

        InputStream fileContent = filePart.getInputStream();
        String sql = "";
        
        if ("student".equals(dataType)) {
            sql = "INSERT INTO student_details (student_name, roll_number, department, year, email) VALUES (?, ?, ?, ?, ?)";
        } else if ("mentor".equals(dataType)) {
            // MENTOR: Dropped Year
            sql = "INSERT INTO mentor_details (name, unique_id, department, email) VALUES (?, ?, ?, ?)";
        } else if ("faculty".equals(dataType)) { 
            sql = "INSERT INTO faculty_details (name, unique_id, department, email) VALUES (?, ?, ?, ?)";
        } else if ("alumni".equals(dataType)) {
            sql = "INSERT INTO alumni_details (name, roll_number, department, email) VALUES (?, ?, ?, ?)";
        } else if ("admin".equals(dataType)) {
            sql = "INSERT INTO admin_details (name, unique_id, email) VALUES (?, ?, ?)";
        } else {
            response.sendRedirect("error.jsp");
            return;
        }

        try {
            Workbook workbook = new XSSFWorkbook(fileContent);
            Sheet sheet = workbook.getSheetAt(0);
            DataFormatter formatter = new DataFormatter();

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
                
                PreparedStatement ps = con.prepareStatement(sql);

                for (Row row : sheet) {
                    if (row.getRowNum() == 0) continue; 

                    String val0 = formatter.formatCellValue(row.getCell(0)).trim(); // Name
                    String val1 = formatter.formatCellValue(row.getCell(1)).trim(); // ID / Roll
                    String val2 = formatter.formatCellValue(row.getCell(2)).trim(); // Dept (OR Admin Email)
                    String val3 = formatter.formatCellValue(row.getCell(3)).trim(); // Year (OR Fac/Alum/Men Email)
                    String val4 = formatter.formatCellValue(row.getCell(4)).trim(); // Student Email

                    if (!val0.isEmpty() && !val1.isEmpty()) {
                        ps.setString(1, val0);
                        ps.setString(2, val1);
                        
                        if ("student".equals(dataType)) {
                            ps.setString(3, val2); 
                            ps.setString(4, val3); 
                            ps.setString(5, val4); 
                        } else if ("mentor".equals(dataType) || "faculty".equals(dataType) || "alumni".equals(dataType)) {
                            ps.setString(3, val2); // Dept
                            ps.setString(4, val3); // Email (Val3)
                        } else if ("admin".equals(dataType)) {
                            ps.setString(3, val2); // Email (Val2)
                        }
                        ps.addBatch();
                    }
                }
                ps.executeBatch();
            }
            workbook.close();
            response.sendRedirect("home.jsp?msg=Success: Data uploaded successfully");

        } catch (Exception e) {
            e.printStackTrace();
            response.sendRedirect("home.jsp?msg=Error: " + e.getMessage());
        }
    }
}