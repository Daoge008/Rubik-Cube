import random
import sys

_faceRotCW = [6, 3, 0, 7, 4, 1, 8, 5, 2]

def rotateFaceCW(lst, faceIndex):
    base = faceIndex * 9
    old = [lst[base + i] for i in range(9)]
    for i in range(9):
        lst[base + i] = old[_faceRotCW[i]]

def cycleStrips(lst, a, b, c, d):
    temp = [lst[d[0]], lst[d[1]], lst[d[2]]]
    lst[d[0]] = lst[c[0]]; lst[d[1]] = lst[c[1]]; lst[d[2]] = lst[c[2]]
    lst[c[0]] = lst[b[0]]; lst[c[1]] = lst[b[1]]; lst[c[2]] = lst[b[2]]
    lst[b[0]] = lst[a[0]]; lst[b[1]] = lst[a[1]]; lst[b[2]] = lst[a[2]]
    lst[a[0]] = temp[0]; lst[a[1]] = temp[1]; lst[a[2]] = temp[2]

def applyBaseMoveCW(lst, face):
    if face == 'U':
        rotateFaceCW(lst, 0)
        cycleStrips(lst, [45, 46, 47], [9, 10, 11], [18, 19, 20], [36, 37, 38])
    elif face == 'D':
        rotateFaceCW(lst, 3)
        cycleStrips(lst, [24, 25, 26], [15, 16, 17], [51, 52, 53], [42, 43, 44])
    elif face == 'F':
        rotateFaceCW(lst, 2)
        cycleStrips(lst, [6, 7, 8], [9, 12, 15], [29, 28, 27], [44, 41, 38])
    elif face == 'B':
        rotateFaceCW(lst, 5)
        cycleStrips(lst, [0, 1, 2], [42, 39, 36], [35, 34, 33], [11, 14, 17])
    elif face == 'R':
        rotateFaceCW(lst, 1)
        cycleStrips(lst, [2, 5, 8], [51, 48, 45], [29, 32, 35], [20, 23, 26])
    elif face == 'L':
        rotateFaceCW(lst, 4)
        cycleStrips(lst, [0, 3, 6], [18, 21, 24], [27, 30, 33], [53, 50, 47])

def applyMove(lst, move):
    f = move[0]
    turns = 1
    if '2' in move: turns = 2
    elif "'" in move: turns = 3
    for _ in range(turns):
        applyBaseMoveCW(lst, f)

U, R, F, D, L, B = 0, 1, 2, 3, 4, 5
cornerFacelet = [
    [ 8,  9, 20 ], [ 6, 18, 38 ], [ 0, 36, 47 ], [ 2, 45, 11 ],
    [ 29, 26, 15 ], [ 27, 44, 24 ], [ 33, 53, 42 ], [ 35, 17, 51 ]
]
edgeFacelet = [
    [ 5, 10 ], [ 7, 19 ], [ 3, 37 ], [ 1, 46 ],
    [ 32, 16 ], [ 28, 25 ], [ 30, 43 ], [ 34, 52 ],
    [ 23, 12 ], [ 21, 41 ], [ 48, 39 ], [ 50, 14 ]
]
cornerColors = [
    [ U, R, F ], [ U, F, L ], [ U, L, B ], [ U, B, R ],
    [ D, F, R ], [ D, L, F ], [ D, B, L ], [ D, R, B ]
]
edgeColors = [
    [ U, R ], [ U, F ], [ U, L ], [ U, B ],
    [ D, R ], [ D, F ], [ D, L ], [ D, B ],
    [ F, R ], [ F, L ], [ B, L ], [ B, R ]
]
char_map = {'U':0, 'R':1, 'F':2, 'D':3, 'L':4, 'B':5}

def matchCorner(c1, c2, c3):
    s = sorted([c1, c2, c3])
    for p in range(8):
        if sorted(cornerColors[p]) == s: return p
    return -1

def matchEdge(c1, c2):
    for p in range(12):
        if (c1 == edgeColors[p][0] and c2 == edgeColors[p][1]) or (c1 == edgeColors[p][1] and c2 == edgeColors[p][0]): return p
    return -1

def getPermutationParity(arr):
    inv = 0
    for i in range(len(arr) - 1):
        for j in range(i + 1, len(arr)):
            if arr[i] > arr[j]: inv += 1
    return inv % 2

def validate(facelets):
    cp = [0]*8; co = [0]*8
    cornerSeen = [False]*8
    for i in range(8):
        fac = [char_map[facelets[cornerFacelet[i][j]]] for j in range(3)]
        ori = 0
        if fac[1] == U or fac[1] == D: ori = 1
        elif fac[2] == U or fac[2] == D: ori = 2
        co[i] = ori
        p = matchCorner(*fac)
        if p < 0: return False, f'invalid corner {i} ({fac})'
        if cornerSeen[p]: return False, f'dup corner {p}'
        cornerSeen[p] = True
        cp[i] = p

    ep = [0]*12; eo = [0]*12
    edgeSeen = [False]*12
    for i in range(12):
        c1 = char_map[facelets[edgeFacelet[i][0]]]
        c2 = char_map[facelets[edgeFacelet[i][1]]]
        ori = 0
        if c1 == U or c1 == D: ori = 0
        elif c2 == U or c2 == D: ori = 1
        elif c1 == F or c1 == B: ori = 0
        else: ori = 1
        eo[i] = ori
        p = matchEdge(c1, c2)
        if p < 0: return False, f'invalid edge {i} ({c1}, {c2}) indices ({edgeFacelet[i][0]}, {edgeFacelet[i][1]})'
        if edgeSeen[p]: return False, f'dup edge {p}'
        edgeSeen[p] = True
        ep[i] = p

    if sum(co) % 3 != 0: return False, 'twist parity'
    if sum(eo) % 2 != 0: return False, 'flip parity'
    if getPermutationParity(cp) != getPermutationParity(ep): return False, 'perm parity'
    return True, 'OK'

faces = ['U', 'D', 'R', 'L', 'F', 'B']
mods = ['', "'", '2']

# Find the shortest sequence that fails
for m1 in faces:
    for m2 in faces:
        state = list('U'*9 + 'R'*9 + 'F'*9 + 'D'*9 + 'L'*9 + 'B'*9)
        applyMove(state, m1)
        applyMove(state, m2)
        ok, err = validate(''.join(state))
        if not ok:
            print(f'2-move sequence failed: {m1} {m2} -> {err}')
            sys.exit(0)

for m1 in faces:
    for m2 in faces:
        for m3 in faces:
            state = list('U'*9 + 'R'*9 + 'F'*9 + 'D'*9 + 'L'*9 + 'B'*9)
            applyMove(state, m1)
            applyMove(state, m2)
            applyMove(state, m3)
            ok, err = validate(''.join(state))
            if not ok:
                print(f'3-move sequence failed: {m1} {m2} {m3} -> {err}')
                sys.exit(0)

print('All 2-move and 3-move sequences passed')
