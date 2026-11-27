"""Ghep DDL va kiem tra chi doc thanh mot file de Execute truc tiep trong SSMS.

Khong ket noi SQL, khong tu dong chay kiem thu co du lieu gia.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FILES = [*sorted((ROOT/'sql/schema').glob('0[1-5]_*.sql')),
         ROOT/'sql/checks/kiem_tra_cau_truc_buoc6.sql']
OUTPUT = ROOT/'sql/schema/00_chay_buoc6_ssms.sql'


def main():
    header = ('-- SINH TU DONG: python tools/tao_script_buoc6_ssms.py\n'
              '-- Mo file nay trong SSMS va Execute toan bo; khong can SQLCMD mode.\n'
              '-- Database dich: hanoi_air_dw; khong sua/xoa nguon hanoi_air_vn.\n'
              '-- Chinh cac file 01-05 / checks truoc, sau do sinh lai file nay.\n\n')
    OUTPUT.write_text(header+'\n'.join(p.read_text(encoding='utf-8-sig') for p in FILES),encoding='utf-8-sig')
    print(f'{OUTPUT.relative_to(ROOT).as_posix()}: {len(FILES)} scripts')


if __name__=='__main__':
    main()
