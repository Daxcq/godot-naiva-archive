#!/usr/bin/env python3
"""Godot MCP Bridge — 把 Godot 编辑器内的 TCP 控制接口桥接为标准 MCP (stdio) 服务。

Godot 侧的 addons/godot_mcp/plugin.gd 在编辑器进程内监听 127.0.0.1:6400，
接收 {"type": "...", "params": {...}} 形式的 JSON 命令。本脚本作为 MCP server
被 WorkBuddy 启动，把 MCP 的 tools/call 翻译成上述协议。

依赖：仅标准库。
"""

import json
import os
import socket
import sys
import threading

GODOT_HOST = os.environ.get("GODOT_MCP_HOST", "127.0.0.1")
GODOT_PORT = int(os.environ.get("GODOT_MCP_PORT", "6400"))
TIMEOUT = float(os.environ.get("GODOT_MCP_TIMEOUT", "15"))

PROTOCOL_VERSION = "2024-11-05"
SERVER_INFO = {"name": "godot-mcp-bridge", "version": "1.0.0"}


# --------------------------------------------------------------------------
# Godot 侧通信
# --------------------------------------------------------------------------
class GodotError(Exception):
    pass


def send_command(command_type, params=None):
    """向 Godot 编辑器发送一条命令并读取一行 JSON 响应。"""
    params = params or {}
    payload = json.dumps({"type": command_type, "params": params}).encode("utf-8")

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(TIMEOUT)
    try:
        sock.connect((GODOT_HOST, GODOT_PORT))
    except OSError as exc:
        sock.close()
        raise GodotError(
            "无法连接 Godot 编辑器 %s:%d（%s）。请确认：1) Godot 已打开 %s 这个工程；"
            "2) 编辑器里 项目 → 项目设置 → 插件 中 \"Godot MCP\" 已启用；"
            "3) 底部面板出现 MCP 标签页。" % (GODOT_HOST, GODOT_PORT, exc, PROJECT_HINT)
        )

    try:
        sock.sendall(payload)
        chunks = []
        while True:
            try:
                data = sock.recv(65536)
            except socket.timeout:
                break
            if not data:
                break
            chunks.append(data)
            # Godot 侧每条命令回一个完整 JSON，能解析就停
            try:
                json.loads(b"".join(chunks).decode("utf-8"))
                break
            except ValueError:
                continue
    finally:
        sock.close()

    raw = b"".join(chunks).decode("utf-8", "replace").strip()
    if not raw:
        raise GodotError(
            "Godot 没有返回数据。编辑器可能正忙或插件未正确加载；"
            "请查看 Godot 编辑器底部的 MCP 面板日志。"
        )
    try:
        return json.loads(raw)
    except ValueError:
        raise GodotError("Godot 返回了非 JSON 内容：%s" % raw[:500])


PROJECT_HINT = os.environ.get("GODOT_PROJECT_PATH", "<你的 Godot 工程目录>")


def call_godot(command_type, params=None):
    """调用 Godot 并把结果规整成 (是否成功, 文本/数据)。"""
    result = send_command(command_type, params)
    if not isinstance(result, dict):
        return False, "Godot 返回异常格式：%r" % (result,)
    if result.get("status") == "error":
        return False, result.get("error", "未知错误")
    payload = result.get("result", result)
    if isinstance(payload, dict) and "error" in payload:
        return False, payload["error"]
    return True, payload


def as_text(payload):
    if isinstance(payload, str):
        return payload
    return json.dumps(payload, ensure_ascii=False, indent=2)


# --------------------------------------------------------------------------
# MCP tool 定义
# --------------------------------------------------------------------------
TOOLS = [
    {
        "name": "godot_ping",
        "description": "检测 Godot 编辑器 MCP 插件是否在线，返回 pong 表示连接正常。",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "godot_get_scene_info",
        "description": "获取当前在 Godot 编辑器中打开的场景的完整节点树（含类型、变换、挂载的脚本）。这是了解场景结构的首选工具。",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "godot_open_scene",
        "description": "在 Godot 编辑器中打开一个场景文件。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scene_path": {"type": "string", "description": "场景资源路径，如 res://scenes/archive_space.tscn"},
                "save_current": {"type": "boolean", "description": "打开前是否先保存当前场景", "default": False},
            },
            "required": ["scene_path"],
        },
    },
    {
        "name": "godot_save_scene",
        "description": "保存 Godot 编辑器中当前打开的场景。",
        "inputSchema": {"type": "object", "properties": {}},
    },
    {
        "name": "godot_new_scene",
        "description": "新建一个空场景文件（根节点为 Node）。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "scene_path": {"type": "string", "description": "新场景路径，如 res://scenes/foo.tscn"},
                "overwrite": {"type": "boolean", "default": False},
            },
            "required": ["scene_path"],
        },
    },
    {
        "name": "godot_find_nodes",
        "description": "按名称（子串匹配）在当前场景中递归查找节点，返回 name / path / type。",
        "inputSchema": {
            "type": "object",
            "properties": {"name": {"type": "string", "description": "要查找的名称片段"}},
            "required": ["name"],
        },
    },
    {
        "name": "godot_get_node_properties",
        "description": "获取指定节点（名称或路径）的类型、变换、脚本、子节点与父节点信息。",
        "inputSchema": {
            "type": "object",
            "properties": {"name": {"type": "string", "description": "节点名或节点路径"}},
            "required": ["name"],
        },
    },
    {
        "name": "godot_create_node",
        "description": "在当前场景根节点下创建节点，支持 MESH/CUBE/SPHERE/CYLINDER/PLANE/CAMERA3D/LIGHT/SPOTLIGHT/OMNILIGHT/STATICBODY3D/CHARACTERBODY3D/AREA3D/COLLISIONSHAPE3D/NODE2D/SPRITE2D/BUTTON/LABEL/VBOX 或任意 ClassDB 类名。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "type": {"type": "string", "description": "节点类型"},
                "name": {"type": "string", "description": "节点名（留空自动生成）"},
                "location": {"type": "array", "items": {"type": "number"}, "description": "[x,y,z]"},
                "rotation": {"type": "array", "items": {"type": "number"}, "description": "[x,y,z] 角度"},
                "scale": {"type": "array", "items": {"type": "number"}, "description": "[x,y,z]"},
                "replace_if_exists": {"type": "boolean", "default": False},
            },
            "required": ["type"],
        },
    },
    {
        "name": "godot_create_child_node",
        "description": "在指定父节点下创建子节点。参数与 godot_create_node 相同，额外需要 parent_name。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "parent_name": {"type": "string", "description": "父节点名或路径，填 root 表示场景根节点"},
                "type": {"type": "string", "description": "节点类型"},
                "name": {"type": "string", "description": "节点名"},
                "location": {"type": "array", "items": {"type": "number"}},
                "rotation": {"type": "array", "items": {"type": "number"}},
                "scale": {"type": "array", "items": {"type": "number"}},
                "replace_if_exists": {"type": "boolean", "default": False},
            },
            "required": ["parent_name", "type"],
        },
    },
    {
        "name": "godot_delete_node",
        "description": "从当前场景删除指定节点。",
        "inputSchema": {
            "type": "object",
            "properties": {"name": {"type": "string", "description": "节点名或路径"}},
            "required": ["name"],
        },
    },
    {
        "name": "godot_set_node_transform",
        "description": "设置 3D 节点的位置 / 旋转（角度）/ 缩放。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "name": {"type": "string"},
                "location": {"type": "array", "items": {"type": "number"}},
                "rotation": {"type": "array", "items": {"type": "number"}},
                "scale": {"type": "array", "items": {"type": "number"}},
            },
            "required": ["name"],
        },
    },
    {
        "name": "godot_set_property",
        "description": "设置节点的任意属性，支持 \"position:x\" 这类子属性写法。值会按属性当前类型自动转换，也可用 force_type 指定 bool/int/float/string/Vector2/Vector3/Color。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "node_name": {"type": "string"},
                "property_name": {"type": "string"},
                "value": {},
                "force_type": {"type": "string"},
            },
            "required": ["node_name", "property_name", "value"],
        },
    },
    {
        "name": "godot_set_parent",
        "description": "调整节点层级：把 child_name 挂到 parent_name 下，默认保持全局变换。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "child_name": {"type": "string"},
                "parent_name": {"type": "string"},
                "keep_global_transform": {"type": "boolean", "default": True},
            },
            "required": ["child_name", "parent_name"],
        },
    },
    {
        "name": "godot_set_material",
        "description": "给 MeshInstance3D / CSGShape3D 设置材质颜色。material_name 留空则用临时实例材质，不会落盘。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "object_name": {"type": "string"},
                "material_name": {"type": "string"},
                "color": {"type": "array", "items": {"type": "number"}, "description": "[r,g,b] 或 [r,g,b,a]，0—1"},
                "create_if_missing": {"type": "boolean", "default": True},
            },
            "required": ["object_name"],
        },
    },
    {
        "name": "godot_set_mesh",
        "description": "给 MeshInstance3D 创建并设置网格。mesh_type 支持 BOXMESH / SPHEREMESH / CAPSULEMESH / CYLINDERMESH / PLANEMESH，可带 size/radius/height。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "node_name": {"type": "string"},
                "mesh_type": {"type": "string"},
                "size": {"type": "array", "items": {"type": "number"}},
                "radius": {"type": "number"},
                "height": {"type": "number"},
            },
            "required": ["node_name", "mesh_type"],
        },
    },
    {
        "name": "godot_set_collision_shape",
        "description": "给 CollisionShape3D/2D 创建并设置碰撞形状。shape_type 支持 BOXSHAPE3D / SPHERESHAPE3D / CAPSULESHAPE3D / CYLINDERSHAPE3D / WORLDBOUNDARYSHAPE3D / CIRCLESHAPE2D / RECTANGLESHAPE2D / CAPSULESHAPE2D。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "node_name": {"type": "string"},
                "shape_type": {"type": "string"},
                "shape_params": {"type": "object", "description": "如 {\"size\":[1,1,1]} 或 {\"radius\":0.5}"},
            },
            "required": ["node_name", "shape_type"],
        },
    },
    {
        "name": "godot_list_assets",
        "description": "列出工程某个目录下的资源文件及其类型。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "folder": {"type": "string", "default": "res://", "description": "如 res://scenes"},
                "type": {"type": "string", "description": "scene / script / texture / material / prefab，留空为全部"},
                "search_pattern": {"type": "string", "default": "*"},
            },
        },
    },
    {
        "name": "godot_list_scripts",
        "description": "列出指定目录下的所有 .gd / .cs 脚本。",
        "inputSchema": {
            "type": "object",
            "properties": {"folder_path": {"type": "string", "default": "res://scripts"}},
        },
    },
    {
        "name": "godot_read_script",
        "description": "读取一个脚本文件的完整内容。",
        "inputSchema": {
            "type": "object",
            "properties": {"script_path": {"type": "string", "description": "如 res://scripts/main.gd"}},
            "required": ["script_path"],
        },
    },
    {
        "name": "godot_create_script",
        "description": "新建 GDScript 文件。content 留空则生成模板。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script_name": {"type": "string"},
                "script_folder": {"type": "string", "default": "res://scripts"},
                "script_type": {"type": "string", "default": "Node", "description": "extends 的基类"},
                "namespace": {"type": "string", "description": "可选 class_name"},
                "content": {"type": "string"},
                "overwrite": {"type": "boolean", "default": False},
            },
            "required": ["script_name"],
        },
    },
    {
        "name": "godot_update_script",
        "description": "覆盖写入脚本内容。注意：这会直接改磁盘文件，请先读取再改。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "script_path": {"type": "string"},
                "content": {"type": "string"},
                "create_if_missing": {"type": "boolean", "default": False},
                "create_folder_if_missing": {"type": "boolean", "default": False},
            },
            "required": ["script_path", "content"],
        },
    },
    {
        "name": "godot_create_prefab",
        "description": "把场景中已有节点打包保存为独立场景文件（prefab）。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "object_name": {"type": "string"},
                "prefab_path": {"type": "string"},
                "overwrite": {"type": "boolean", "default": False},
            },
            "required": ["object_name", "prefab_path"],
        },
    },
    {
        "name": "godot_instantiate_prefab",
        "description": "把场景文件实例化到当前场景中。",
        "inputSchema": {
            "type": "object",
            "properties": {
                "prefab_path": {"type": "string"},
                "position_x": {"type": "number"},
                "position_y": {"type": "number"},
                "position_z": {"type": "number"},
                "rotation_x": {"type": "number"},
                "rotation_y": {"type": "number"},
                "rotation_z": {"type": "number"},
            },
            "required": ["prefab_path"],
        },
    },
    {
        "name": "godot_editor_control",
        "description": "控制编辑器：PLAY 运行主场景 / STOP 停止 / SAVE 保存当前场景。",
        "inputSchema": {
            "type": "object",
            "properties": {"command": {"type": "string", "enum": ["PLAY", "STOP", "SAVE"]}},
            "required": ["command"],
        },
    },
]

# MCP tool 名 → Godot 命令类型
ROUTING = {
    "godot_get_scene_info": "GET_SCENE_INFO",
    "godot_open_scene": "OPEN_SCENE",
    "godot_save_scene": "SAVE_SCENE",
    "godot_new_scene": "NEW_SCENE",
    "godot_find_nodes": "FIND_OBJECTS_BY_NAME",
    "godot_get_node_properties": "GET_OBJECT_PROPERTIES",
    "godot_create_node": "CREATE_OBJECT",
    "godot_create_child_node": "CREATE_CHILD_OBJECT",
    "godot_delete_node": "DELETE_OBJECT",
    "godot_set_node_transform": "SET_OBJECT_TRANSFORM",
    "godot_set_property": "SET_PROPERTY",
    "godot_set_parent": "SET_PARENT",
    "godot_set_material": "SET_MATERIAL",
    "godot_set_mesh": "SET_MESH",
    "godot_set_collision_shape": "SET_COLLISION_SHAPE",
    "godot_list_assets": "GET_ASSET_LIST",
    "godot_list_scripts": "LIST_SCRIPTS",
    "godot_read_script": "VIEW_SCRIPT",
    "godot_create_script": "CREATE_SCRIPT",
    "godot_update_script": "UPDATE_SCRIPT",
    "godot_create_prefab": "CREATE_PREFAB",
    "godot_instantiate_prefab": "INSTANTIATE_PREFAB",
    "godot_editor_control": "EDITOR_CONTROL",
}


def dispatch(tool_name, arguments):
    if tool_name == "godot_ping":
        return call_godot("ping")
    command = ROUTING.get(tool_name)
    if command is None:
        return False, "未知工具：%s" % tool_name
    return call_godot(command, arguments or {})


# --------------------------------------------------------------------------
# MCP stdio 协议
# --------------------------------------------------------------------------
_write_lock = threading.Lock()


def write_message(message):
    body = json.dumps(message, ensure_ascii=False).encode("utf-8")
    header = ("Content-Length: %d\r\n\r\n" % len(body)).encode("ascii")
    with _write_lock:
        sys.stdout.buffer.write(header + body)
        sys.stdout.buffer.flush()


def read_message(stream):
    headers = {}
    while True:
        line = stream.readline()
        if not line:
            return None
        line = line.strip()
        if not line:
            break
        if b":" in line:
            key, _, value = line.partition(b":")
            headers[key.strip().lower()] = value.strip()
    length = int(headers.get(b"content-length", b"0"))
    if length <= 0:
        return None
    return json.loads(stream.read(length).decode("utf-8"))


def handle_request(request):
    method = request.get("method")
    request_id = request.get("id")

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "protocolVersion": PROTOCOL_VERSION,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
            },
        }
    if method == "notifications/initialized":
        return None
    if method == "ping":
        return {"jsonrpc": "2.0", "id": request_id, "result": {}}
    if method == "tools/list":
        return {"jsonrpc": "2.0", "id": request_id, "result": {"tools": TOOLS}}
    if method == "tools/call":
        params = request.get("params") or {}
        name = params.get("name")
        args = params.get("arguments") or {}
        try:
            ok, payload = dispatch(name, args)
        except GodotError as exc:
            ok, payload = False, str(exc)
        except Exception as exc:  # noqa: BLE001
            ok, payload = False, "桥接异常：%r" % (exc,)
        return {
            "jsonrpc": "2.0",
            "id": request_id,
            "result": {
                "content": [{"type": "text", "text": as_text(payload)}],
                "isError": not ok,
            },
        }
    if request_id is None:
        return None
    return {
        "jsonrpc": "2.0",
        "id": request_id,
        "error": {"code": -32601, "message": "Method not found: %s" % method},
    }


def main():
    stream = sys.stdin.buffer
    while True:
        try:
            request = read_message(stream)
        except Exception:  # noqa: BLE001
            break
        if request is None:
            break
        response = handle_request(request)
        if response is not None:
            write_message(response)


if __name__ == "__main__":
    main()
