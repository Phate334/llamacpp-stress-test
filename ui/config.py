from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    project_name: str = "Llama.cpp Stress Test"
    result_dir: str = "/app/results"

    class Config:
        env_file = ".env"


settings = Settings()  # type: ignore
