import os
import shutil
import subprocess
import zipfile


def main() -> None:
    if os.path.exists("lambda-package"):
        shutil.rmtree("lambda-package")
    if os.path.exists("lambda-deployment.zip"):
        os.remove("lambda-deployment.zip")

    os.makedirs("lambda-package", exist_ok=True)

    subprocess.run(
        [
            "docker", "run", "--rm", "-v", f"{os.getcwd()}:/var/task",
            "--platform", "linux/amd64", "--entrypoint", "",
            "public.ecr.aws/lambda/python:3.12",
            "/bin/sh", "-c",
            "pip install --target /var/task/lambda-package -r /var/task/requirements.txt --platform manylinux2014_x86_64 --only-binary=:all: --upgrade",
        ],
        check=True,
    )

    for file in ["server.py", "lambda_handler.py", "context.py", "resources.py"]:
        shutil.copy2(file, "lambda-package/")

    if os.path.exists("data"):
        shutil.copytree("data", "lambda-package/data")

    with zipfile.ZipFile("lambda-deployment.zip", "w", zipfile.ZIP_DEFLATED) as zipf:
        for root, _, files in os.walk("lambda-package"):
            for f in files:
                path = os.path.join(root, f)
                zipf.write(path, os.path.relpath(path, "lambda-package"))

    print("Created backend/lambda-deployment.zip")


if __name__ == "__main__":
    main()
