package com.dontlift.security;

import com.dontlift.auth.JwtService;
import jakarta.servlet.Filter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.context.annotation.Import;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.context.web.WebAppConfiguration;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.context.WebApplicationContext;
import org.springframework.web.servlet.config.annotation.EnableWebMvc;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.UUID;

import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebAppConfiguration
@ContextConfiguration(classes = SecurityConfigTest.TestConfig.class)
@ExtendWith(SpringExtension.class)
class SecurityConfigTest {

    @Autowired
    private WebApplicationContext applicationContext;

    @Autowired
    private Filter springSecurityFilterChain;

    @Autowired
    private JwtService jwtService;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(applicationContext)
                .addFilters(springSecurityFilterChain)
                .build();
    }

    @Test
    void missingCredentialsReturnsUnauthorized() throws Exception {
        mockMvc.perform(get("/teams"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void invalidJwtReturnsUnauthorized() throws Exception {
        given(jwtService.parse("invalid-token")).willReturn(null);

        mockMvc.perform(get("/teams").header("Authorization", "Bearer invalid-token"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void validJwtReachesProtectedController() throws Exception {
        given(jwtService.parse("valid-token")).willReturn(UUID.randomUUID());

        mockMvc.perform(get("/teams").header("Authorization", "Bearer valid-token"))
                .andExpect(status().isOk());
    }

    @RestController
    static class ProtectedController {

        @GetMapping("/teams")
        String protectedEndpoint() {
            return "ok";
        }
    }

    @Configuration(proxyBeanMethods = false)
    @EnableWebMvc
    @EnableWebSecurity
    @Import(SecurityConfig.class)
    static class TestConfig {

        @Bean
        JwtService jwtService() {
            return mock(JwtService.class);
        }

        @Bean
        ProtectedController protectedController() {
            return new ProtectedController();
        }
    }
}
