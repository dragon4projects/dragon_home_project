from pathlib import Path
import json, subprocess, tempfile
from PIL import Image
PROJECT=Path(__file__).resolve().parents[1]
SCRIPT=PROJECT/"tools/create_private_review_sheet.py"
with tempfile.TemporaryDirectory() as temp:
    root=Path(temp)/"game"
    (root/"data").mkdir(parents=True)
    ref="assets/residents/RES_01/identity/ref.png"
    frame="assets/residents/RES_01/wardrobes/SHORT/IDLE_S/0001.png"
    for rel,rgba in [(ref,(102,77,82,255)),(frame,(218,154,137,230))]:
        path=root/rel
        path.parent.mkdir(parents=True,exist_ok=True)
        Image.new("RGBA",(96,128),rgba).save(path)
    doc={"schema":1,"residents":{
        "RES_01":{"display_name":"Мора","identity_references":[ref],
          "default_wardrobe":"SHORT",
          "wardrobes":{"SHORT":{"states":{"IDLE_S":{"status":"PASS","frames":[frame]}}}}},
        "RES_22":{"display_name":"Вея","identity_references":[],
          "wardrobes":{}}
    }}
    (root/"data/asset_registry_nov2026.json").write_text(json.dumps(doc,ensure_ascii=False),encoding="utf8")
    out=Path(temp)/"private.png"
    r=subprocess.run(["python3",str(SCRIPT),"--project",str(root),"--output",str(out)],
                     capture_output=True,text=True)
    assert r.returncode==0,r.stderr
    stats=json.loads(r.stdout)
    assert stats["cards"]==2 and stats["sprite_banks_with_pixels"]==1
    with Image.open(out) as im:
        assert im.size==(2350,432)
    print("CONTACT_SHEET_TEST_PASS 2 cards, 1 candidate, 1 missing, originals unchanged")

