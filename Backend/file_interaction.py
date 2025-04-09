import json

class FileSystem:
    @staticmethod
    def retrieve_txt(file_path: str) -> str:
        with open(file_path, 'r') as f:
            return f.read()

    @staticmethod
    def write_txt(file_path: str, content: str) -> None:
        with open(file_path, 'w') as f:
            f.write(content)

    @staticmethod
    def append_txt(file_path: str, content: str) -> None:
        with open(file_path, 'a') as f:
            f.write(content)

    @staticmethod
    def retrieve_json(file_path: str) -> dict:
        with open(file_path, 'r') as f:
            return json.load(f)

    @staticmethod
    def write_json(file_path: str, content: dict) -> None:
        with open(file_path, 'w') as f:
            json.dump(content, f, indent=4)

    @staticmethod
    def change_json_value(file_path: str, key: str, value: any) -> None:
        with open(file_path, 'r') as f:
            content = json.load(f)
        content[key] = value
        with open(file_path, 'w') as f:
            json.dump(content, f, indent=4)