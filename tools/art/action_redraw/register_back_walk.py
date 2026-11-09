import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[3]
RUN = ROOT / 'output/art/CHR-001/2026-11-05-back-walk-v1'
SOURCE = ROOT / 'assets/characters/action-redraw-v1/back-walk-v1'
RUNTIME = ROOT / 'godot/assets/characters/action-redraw-v1'


def main():
    for folder in [RUN / 'source', RUN / 'frames', RUN / 'review', SOURCE]:
        folder.mkdir(parents=True, exist_ok=True)
    image = Image.open(RUN / 'source/revised.png').convert('RGBA')
    width, height = image.width // 4, image.height // 2
    assert (width, height) == (384, 512)
    frames = []
    geometry = []
    for index in range(8):
        left, top = index % 4 * width, index // 4 * height
        frame = image.crop((left, top, left + width, top + height))
        alpha = frame.getchannel('A')
        bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
        assert bounds and bounds[0] > 8 and bounds[2] < width - 8 and bounds[1] > 8 and bounds[3] < height - 8
        frame.save(RUN / f'frames/frame-{index:02d}.png')
        frames.append(frame)
        geometry.append({'frame': index, 'alpha_bbox_128': list(bounds), 'sha256': hashlib.sha256(frame.tobytes()).hexdigest()})
    data = {'size': [384, 512], 'columns': 4, 'root': [180, 450], 'scale': 0.1485, 'frame_count': 8, 'distance_per_frame': 22.0, 'anchor_kind': 'shared virtual ground origin under hip; not each frame alpha bottom', 'source': 'assets/characters/action-redraw-v1/back-walk-v1/hero-back-walk.png'}
    shutil.copy2(RUN / 'source/revised.png', SOURCE / 'hero-back-walk.png')
    shutil.copy2(SOURCE / 'hero-back-walk.png', RUNTIME / 'hero-back-walk.png')
    (SOURCE / 'clips.json').write_text(json.dumps({'hero-back-walk': data}, indent=2) + '\n')
    clips_path = RUNTIME / 'clips.json'
    clips = json.loads(clips_path.read_text())
    clips['hero-back-walk'] = data
    clips_path.write_text(json.dumps(clips, indent=2) + '\n')
    old = Image.open(RUNTIME / 'hero-back-full.png').crop((0, 0, 543, 724))
    previews = []
    for frame in frames:
        canvas = Image.new('RGBA', (520, 320), '#ddd7ca')
        draw = ImageDraw.Draw(canvas)
        draw.text((75, 12), 'IDLE', fill='black')
        draw.text((320, 12), 'WALK', fill='black')
        for sprite, root, scale, center in [(old, (272, 700), 0.12, 130), (frame, (180, 450), 0.1485, 390)]:
            ratio = scale * 2 / 3 * 4
            rendered = sprite.resize((round(sprite.width * ratio), round(sprite.height * ratio)), Image.Resampling.LANCZOS)
            canvas.alpha_composite(rendered, (round(center - root[0] * ratio), round(260 - root[1] * ratio)))
        previews.append(canvas.convert('RGB'))
    previews[0].save(RUN / 'review/idle-walk.gif', save_all=True, append_images=previews[1:], duration=100, loop=0)
    previews[0].save(RUN / 'review/idle-walk.png')
    record = {'art_source': 'host_image', 'tool': 'image_gen.imagegen', 'model': 'not returned by tool', 'cost': 'not returned by tool', 'date': '2026-11-05', 'reference': 'godot/assets/characters/action-redraw-v1/hero-back-full.png', 'reference_sha256': hashlib.sha256((RUNTIME / 'hero-back-full.png').read_bytes()).hexdigest(), 'selected_source_sha256': hashlib.sha256((SOURCE / 'hero-back-walk.png').read_bytes()).hexdigest(), 'processing': 'uniform 4x2 crop only; source alpha unchanged; one fixed scale and root across all frames', 'frames': geometry, 'clip': data, 'visual_review': 'AI selected revision for clearer left-right leg alternation; native playback and user approval pending'}
    (RUN / 'generation.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    provenance_path = SOURCE.parent / 'provenance.json'
    provenance = json.loads(provenance_path.read_text())
    runtime_path = str((RUNTIME / 'hero-back-walk.png').relative_to(ROOT))
    provenance['sources'] = [entry for entry in provenance['sources'] if entry['runtime'] != runtime_path]
    provenance['sources'].append({'source': str((SOURCE / 'hero-back-walk.png').relative_to(ROOT)), 'runtime': runtime_path, 'sha256': record['selected_source_sha256'], 'art_source': 'image_gen.imagegen', 'candidate': str((RUN / 'source/revised.png').relative_to(ROOT)), 'revision': 'v1: eight rear walk poses with corrected alternating legs'})
    provenance_path.write_text(json.dumps(provenance, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({'source': str(SOURCE), 'preview': str(RUN / 'review/idle-walk.gif'), 'geometry': geometry}, ensure_ascii=False))


if __name__ == '__main__':
    main()
