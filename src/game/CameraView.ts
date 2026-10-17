import type { Point } from './TrainingRoom';

export function cameraView(player: Point, width: number, height: number, worldWidth: number, worldHeight: number) {
  const zoom = Math.max(height / 720, width / worldWidth, height / worldHeight);
  const visibleWidth = width / zoom;
  const visibleHeight = height / zoom;
  return {
    zoom,
    x: Math.max(0, Math.min(worldWidth - visibleWidth, player.x - visibleWidth / 2)),
    y: Math.max(0, Math.min(worldHeight - visibleHeight, player.y - visibleHeight / 2)),
  };
}

export function screenToWorld(point: Point, view: ReturnType<typeof cameraView>): Point {
  return { x: point.x / view.zoom + view.x, y: point.y / view.zoom + view.y };
}
