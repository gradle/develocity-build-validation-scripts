package com.gradle.enterprise.network;

import com.gradle.enterprise.cli.ConsoleLogger;

import java.io.BufferedReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;

public class NetworkSettingsConfigurator {

    public static void configureNetworkSettings(Path networkSettingsFile, ConsoleLogger logger) {
        try {
            configureBasedOnProperties(networkSettingsFile, logger);
        } catch (IOException e) {
            throw new FailedToLoadNetworkSettingsException(networkSettingsFile, e);
        }
    }

    private static void configureBasedOnProperties(Path networkSettingsFile, ConsoleLogger logger) throws IOException {
        if (Files.isRegularFile(networkSettingsFile)) {
            logger.debug("Loading network settings from " + networkSettingsFile.toAbsolutePath());
            Properties proxyProps = loadProperties(networkSettingsFile);
            proxyProps.stringPropertyNames().stream()
                .filter(NetworkSettingsConfigurator::isNetworkProperty)
                .forEach(key -> System.setProperty(key, proxyProps.getProperty(key)));
        }
    }

    private static boolean isNetworkProperty(String key) {
        return isSslProperty(key) || isProxyProperty(key) || isTimeoutProperty(key);
    }
    private static boolean isSslProperty(String key) {
        return key.startsWith("javax.net.ssl")
            || key.equals("ssl.allowUntrustedServer");
    }

    private static boolean isProxyProperty(String key) {
        return key.startsWith("http.proxy")
            || key.startsWith("https.proxy")
            || key.startsWith("socksProxy")
            || key.endsWith(".nonProxyHosts");
    }

    private static boolean isTimeoutProperty(String key) {
        return key.startsWith("timeout");
    }

    private static Properties loadProperties(Path propertiesFile) throws IOException {
        Properties properties = new Properties();
        try (BufferedReader in = Files.newBufferedReader(propertiesFile)) {
            properties.load(in);
            return properties;
        }
    }
}
