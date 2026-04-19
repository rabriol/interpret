package main

import (
	"os"

	"gopkg.in/yaml.v3"
)

type Channel struct {
	ID   int    `yaml:"id"`
	Name string `yaml:"name"`
}

type Config struct {
	SSID     string    `yaml:"ssid"`
	Password string    `yaml:"password"`
	Channels []Channel `yaml:"channels"`
}

func loadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
