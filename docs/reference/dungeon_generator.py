from __future__ import annotations

import random
from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Dict, List, Optional, Tuple
from collections import deque


class Direction(Enum):
    NORTH = (0, -1)
    EAST = (1, 0)
    SOUTH = (0, 1)
    WEST = (-1, 0)

    @property
    def dx(self) -> int:
        return self.value[0]

    @property
    def dy(self) -> int:
        return self.value[1]

    def opposite(self) -> "Direction":
        return {
            Direction.NORTH: Direction.SOUTH,
            Direction.EAST: Direction.WEST,
            Direction.SOUTH: Direction.NORTH,
            Direction.WEST: Direction.EAST,
        }[self]


DIRS = [Direction.NORTH, Direction.EAST, Direction.SOUTH, Direction.WEST]


class EdgeType(Enum):
    WALL = auto()
    OPEN = auto()
    DOOR = auto()


class TileType(Enum):
    FLOOR = auto()
    START = auto()
    GOAL = auto()


@dataclass
class Cell:
    tile: TileType = TileType.FLOOR
    edges: Dict[Direction, EdgeType] = field(default_factory=lambda: {
        Direction.NORTH: EdgeType.WALL,
        Direction.EAST: EdgeType.WALL,
        Direction.SOUTH: EdgeType.WALL,
        Direction.WEST: EdgeType.WALL,
    })


@dataclass
class Rect:
    x: int
    y: int
    w: int
    h: int

    @property
    def x2(self) -> int:
        return self.x + self.w - 1

    @property
    def y2(self) -> int:
        return self.y + self.h - 1

    def center(self) -> Tuple[int, int]:
        return (self.x + self.w // 2, self.y + self.h // 2)

    def intersects(self, other: "Rect", margin: int = 1) -> bool:
        return not (
            self.x2 + margin < other.x
            or other.x2 + margin < self.x
            or self.y2 + margin < other.y
            or other.y2 + margin < self.y
        )

    def contains(self, x: int, y: int) -> bool:
        return self.x <= x <= self.x2 and self.y <= y <= self.y2


class FullConnectedWizMap:
    def __init__(self, size: int):
        if size < 8:
            raise ValueError("size は 8 以上くらいがええで")
        self.size = size
        self.grid: List[List[Cell]] = [[Cell() for _ in range(size)] for _ in range(size)]
        self.rooms: List[Rect] = []
        self._init_all_walls()

    # ----------------------------
    # 基本
    # ----------------------------
    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.size and 0 <= y < self.size

    def cell(self, x: int, y: int) -> Cell:
        return self.grid[y][x]

    def _init_all_walls(self) -> None:
        self.grid = [[Cell() for _ in range(self.size)] for _ in range(self.size)]
        self.rooms = []
        for y in range(self.size):
            for x in range(self.size):
                self.cell(x, y).tile = TileType.FLOOR
                for d in DIRS:
                    self.cell(x, y).edges[d] = EdgeType.WALL

    def set_edge(self, x: int, y: int, d: Direction, edge: EdgeType) -> None:
        if not self.in_bounds(x, y):
            return
        self.cell(x, y).edges[d] = edge
        nx, ny = x + d.dx, y + d.dy
        if self.in_bounds(nx, ny):
            self.cell(nx, ny).edges[d.opposite()] = edge

    def get_edge(self, x: int, y: int, d: Direction) -> EdgeType:
        return self.cell(x, y).edges[d]

    def open_between(self, x1: int, y1: int, x2: int, y2: int, edge: EdgeType = EdgeType.OPEN) -> None:
        dx = x2 - x1
        dy = y2 - y1
        if abs(dx) + abs(dy) != 1:
            raise ValueError("隣接セル専用やで")

        if dx == 1:
            self.set_edge(x1, y1, Direction.EAST, edge)
        elif dx == -1:
            self.set_edge(x1, y1, Direction.WEST, edge)
        elif dy == 1:
            self.set_edge(x1, y1, Direction.SOUTH, edge)
        else:
            self.set_edge(x1, y1, Direction.NORTH, edge)

    def can_move(self, x: int, y: int, d: Direction) -> bool:
        nx, ny = x + d.dx, y + d.dy
        return self.in_bounds(nx, ny) and self.get_edge(x, y, d) in (EdgeType.OPEN, EdgeType.DOOR)

    # ----------------------------
    # 全体連結: まず完全迷路を作る
    # ----------------------------
    def carve_perfect_maze(self, rng: random.Random) -> None:
        visited = set()
        stack = [(0, 0)]
        visited.add((0, 0))

        while stack:
            x, y = stack[-1]
            neighbors = []

            for d in DIRS:
                nx, ny = x + d.dx, y + d.dy
                if self.in_bounds(nx, ny) and (nx, ny) not in visited:
                    neighbors.append((d, nx, ny))

            if not neighbors:
                stack.pop()
                continue

            d, nx, ny = rng.choice(neighbors)
            self.open_between(x, y, nx, ny, EdgeType.OPEN)
            visited.add((nx, ny))
            stack.append((nx, ny))

    # ----------------------------
    # 部屋生成
    # ----------------------------
    def generate_rooms(
        self,
        rng: random.Random,
        room_attempts: int,
        min_room_size: int,
        max_room_size: int,
    ) -> None:
        self.rooms = []

        for _ in range(room_attempts):
            w = rng.randint(min_room_size, max_room_size)
            h = rng.randint(min_room_size, max_room_size)

            if w >= self.size - 2 or h >= self.size - 2:
                continue

            x = rng.randint(1, self.size - w - 1)
            y = rng.randint(1, self.size - h - 1)
            room = Rect(x, y, w, h)

            if any(room.intersects(r, margin=1) for r in self.rooms):
                continue

            self.rooms.append(room)

    def carve_room(self, room: Rect) -> None:
        # 部屋内部の壁を全部開ける
        for y in range(room.y, room.y + room.h):
            for x in range(room.x, room.x + room.w):
                if x < room.x2:
                    self.open_between(x, y, x + 1, y, EdgeType.OPEN)
                if y < room.y2:
                    self.open_between(x, y, x, y + 1, EdgeType.OPEN)

    def carve_rooms(self) -> None:
        for room in self.rooms:
            self.carve_room(room)

    # ----------------------------
    # ループや扉を追加
    # ----------------------------
    def add_extra_links(self, rng: random.Random, count: int) -> None:
        candidates: List[Tuple[int, int, Direction]] = []

        for y in range(self.size):
            for x in range(self.size):
                if x < self.size - 1 and self.get_edge(x, y, Direction.EAST) == EdgeType.WALL:
                    candidates.append((x, y, Direction.EAST))
                if y < self.size - 1 and self.get_edge(x, y, Direction.SOUTH) == EdgeType.WALL:
                    candidates.append((x, y, Direction.SOUTH))

        rng.shuffle(candidates)
        for x, y, d in candidates[:count]:
            self.set_edge(x, y, d, EdgeType.OPEN)

    def add_doors_between_room_and_nonroom(self, rng: random.Random, door_chance: float = 0.25) -> None:
        def in_any_room(x: int, y: int) -> bool:
            return any(r.contains(x, y) for r in self.rooms)

        for y in range(self.size):
            for x in range(self.size):
                for d in (Direction.EAST, Direction.SOUTH):
                    nx, ny = x + d.dx, y + d.dy
                    if not self.in_bounds(nx, ny):
                        continue

                    a_in = in_any_room(x, y)
                    b_in = in_any_room(nx, ny)

                    if a_in != b_in and self.get_edge(x, y, d) == EdgeType.OPEN:
                        if rng.random() < door_chance:
                            self.set_edge(x, y, d, EdgeType.DOOR)

    # ----------------------------
    # 解析
    # ----------------------------
    def bfs(self, start: Tuple[int, int]) -> Dict[Tuple[int, int], int]:
        q = deque([start])
        dist = {start: 0}

        while q:
            x, y = q.popleft()
            for d in DIRS:
                if not self.can_move(x, y, d):
                    continue
                nx, ny = x + d.dx, y + d.dy
                if (nx, ny) not in dist:
                    dist[(nx, ny)] = dist[(x, y)] + 1
                    q.append((nx, ny))
        return dist

    def is_fully_connected(self) -> bool:
        return len(self.bfs((0, 0))) == self.size * self.size

    # ----------------------------
    # 開始・ゴール
    # ----------------------------
    def place_start_and_goal(self, rng: random.Random) -> None:
        for y in range(self.size):
            for x in range(self.size):
                self.cell(x, y).tile = TileType.FLOOR

        if self.rooms:
            sx, sy = rng.choice(self.rooms).center()
        else:
            sx, sy = (0, 0)

        dist = self.bfs((sx, sy))
        gx, gy = max(dist.items(), key=lambda kv: kv[1])[0]

        self.cell(sx, sy).tile = TileType.START
        self.cell(gx, gy).tile = TileType.GOAL

    # ----------------------------
    # 生成本体
    # ----------------------------
    def generate(
        self,
        seed: Optional[int] = None,
        room_attempts: Optional[int] = None,
        min_room_size: int = 4,
        max_room_size: Optional[int] = None,
        extra_links: Optional[int] = None,
        door_chance: float = 0.25,
    ) -> None:
        rng = random.Random(seed)
        self._init_all_walls()

        if room_attempts is None:
            room_attempts = max(20, self.size * 3)
        if max_room_size is None:
            max_room_size = max(5, min(8, self.size // 3 + 1))
        if extra_links is None:
            extra_links = max(2, self.size // 4)

        # 1. 全セル連結の迷路
        self.carve_perfect_maze(rng)

        # 2. 部屋を置いて内部を大きく開く
        self.generate_rooms(
            rng=rng,
            room_attempts=room_attempts,
            min_room_size=min_room_size,
            max_room_size=max_room_size,
        )
        self.carve_rooms()

        # 3. 少しループ追加
        self.add_extra_links(rng, extra_links)

        # 4. 部屋境界っぽいところに扉を少し置く
        self.add_doors_between_room_and_nonroom(rng, door_chance=door_chance)

        # 念のため確認
        if not self.is_fully_connected():
            raise RuntimeError("生成後に全体連結が壊れたで。これは想定外や")

        self.place_start_and_goal(rng)

    # ----------------------------
    # 表示
    # ----------------------------
    def tile_char(self, x: int, y: int) -> str:
        t = self.cell(x, y).tile
        if t == TileType.FLOOR:
            return ".."
        if t == TileType.START:
            return "S "
        if t == TileType.GOAL:
            return "G "
        return "??"

    def horizontal_edge_str(self, edge: EdgeType) -> str:
        if edge == EdgeType.WALL:
            return "--"
        if edge == EdgeType.OPEN:
            return "  "
        if edge == EdgeType.DOOR:
            return "++"
        return "##"

    def vertical_edge_str(self, edge: EdgeType) -> str:
        if edge == EdgeType.WALL:
            return "|"
        if edge == EdgeType.OPEN:
            return " "
        if edge == EdgeType.DOOR:
            return "+"
        return "#"

    def render_ascii(self) -> str:
        lines: List[str] = []

        top = "+"
        for x in range(self.size):
            top += self.horizontal_edge_str(self.get_edge(x, 0, Direction.NORTH)) + "+"
        lines.append(top)

        for y in range(self.size):
            body = self.vertical_edge_str(self.get_edge(0, y, Direction.WEST))
            for x in range(self.size):
                body += self.tile_char(x, y)
                body += self.vertical_edge_str(self.get_edge(x, y, Direction.EAST))
            lines.append(body)

            bottom = "+"
            for x in range(self.size):
                bottom += self.horizontal_edge_str(self.get_edge(x, y, Direction.SOUTH)) + "+"
            lines.append(bottom)

        return "\n".join(lines)

    def summary(self) -> str:
        edge_counts = {e: 0 for e in EdgeType}
        for y in range(self.size):
            for x in range(self.size):
                for d in (Direction.EAST, Direction.SOUTH):
                    edge_counts[self.get_edge(x, y, d)] += 1

        return (
            f"size={self.size} / "
            f"rooms={len(self.rooms)} / "
            f"connected={self.is_fully_connected()} / "
            f"edges={{"
            + ", ".join(f"{k.name}:{v}" for k, v in edge_counts.items())
            + "}}"
        )


def generate_full_connected_wiz_map(size: int = 20, seed: Optional[int] = None) -> FullConnectedWizMap:
    m = FullConnectedWizMap(size)
    m.generate(
        seed=seed,
        min_room_size=2,
        max_room_size=5,
        extra_links=3,
        door_chance=0.55,
    )
    return m


if __name__ == "__main__":
    dungeon = generate_full_connected_wiz_map(size=20, seed=20)
    print(dungeon.summary())
    print(dungeon.render_ascii())