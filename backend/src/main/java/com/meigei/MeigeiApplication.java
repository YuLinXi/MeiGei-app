package com.meigei;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
@MapperScan("com.meigei.**.mapper")
public class MeigeiApplication {

    public static void main(String[] args) {
        SpringApplication.run(MeigeiApplication.class, args);
    }
}
