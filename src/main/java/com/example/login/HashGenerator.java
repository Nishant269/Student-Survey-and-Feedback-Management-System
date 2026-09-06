package com.example.login;
import org.mindrot.jbcrypt.BCrypt;

public class HashGenerator {
    public static void main(String[] args) {
        String plainPassword = "1234"; 
        String hashedPassword = BCrypt.hashpw(plainPassword, BCrypt.gensalt());
        System.out.println("COPY THIS HASH: " + hashedPassword);
    }
}