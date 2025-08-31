from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    project_name: str = "Llama.cpp Stress Test"
    result_dir: str = "/tmp/test_results"

    class Config:
        env_file = ".env"


settings = Settings()  # type: ignore