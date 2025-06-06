//
//  Board.swift
//  Minesweeper
//
//  Created by Cameron Goddard on 4/3/22.
//

import Foundation
import SpriteKit
import Defaults

class Board {
    let node: SKShapeNode
    
    let rows, cols, mines : Int
    var minesLayout: [(Int, Int)] = []
    
    var loadedBoard: Bool = false
    
    var revealedTiles = 0
    var availableTiles : Int
    
    var tiles : [[Tile]] // May change this
    
    private var tileSize: CGSize {
        CGSize(
            width: 16 * Util.scale,
            height: 16 * Util.scale
        )
    }
    
    init(rows: Int, cols: Int, mines: Int, minesLayout: [(Int, Int)]?) {
        self.node = SKShapeNode(path: CGPath(rect: CGRect(x: 0, y: 0, width: cols * 16 * Int(Util.scale), height: rows * 16 * Int(Util.scale)), transform: nil), centered: true)
        self.node.lineWidth = 0
        
        self.availableTiles = rows * cols - mines
        
        self.rows = rows
        self.cols = cols
        self.mines = mines
        
        if minesLayout != nil {
            self.minesLayout = minesLayout!
            self.loadedBoard = true
        }
        
        self.tiles = [[Tile]](repeating: [Tile](repeating: Tile(), count: cols), count: rows)
        initBoard()
    }
    
    private func initBoard(restart: Bool = false) {
        // Init tiles
        for r in 0...rows - 1 {
            for c in 0...cols - 1 {
                let tile = Tile(r: r, c: c, state: .Covered)
                self.tiles[r][c] = tile
                node.addChild(tile.node)
            }
        }
        
        // Set tile sizes and positions
        for r in 0...rows - 1 {
            for c in 0...cols - 1 {
                tiles[r][c].node.size = tileSize
                
                let x = node.frame.minX + CGFloat(c) * tileSize.width
                let y = node.frame.maxY - CGFloat(r) * tileSize.height
                
                tiles[r][c].node.position = CGPoint(x: x-CGFloat((4*cols)), y: y+CGFloat((4*rows))-(Util.scale*21.5)) // Temporary fix
            }
        }
        
        // Add mines
        if loadedBoard || restart {
            for (r, c) in minesLayout {
                tiles[r][c].setValue(val: .Mine)
            }
        } else {
            minesLayout = []
            
            var addedMines = 0
            while addedMines < mines {
                for r in 0...rows - 1 {
                    for c in 0...cols - 1 {
                        if Int.random(in: 0...100) == 0 && tiles[r][c].value == .Empty && addedMines < mines {
                            tiles[r][c].setValue(val: .Mine)
                            minesLayout.append((r, c))
                            addedMines += 1
                        }
                    }
                }
            }
        }
        
        // Set adjacency numbers
        setNumbers()
        
        // Calculate total 3BV and send to Stats
        NotificationCenter.default.post(name: .updateStat, object: "test", userInfo: ["Total3BV": calculate3BV()])
    }
    
    func setTextures() {
        for r in 0...rows-1 {
            for c in 0...cols-1 {
                let tile = tileAt(r: r, c: c)!
                tile.setState(state: tile.state)
            }
        }
    }
    
    private func numberOfAdjacentMines(r: Int, c: Int) -> Int {
        var ret = 0
        for tile in getAdjacentTiles(r: r, c: c) {
            if tile.value == .Mine {
                ret += 1
            }
        }
        return ret
    }

    private func getAdjacentTiles(r: Int, c: Int) -> [Tile] {
        var ret = [Tile]()
        if let tile = tileAt(r: r-1, c: c) { ret.append(tile)}
        if let tile = tileAt(r: r-1, c: c-1) { ret.append(tile)}
        if let tile = tileAt(r: r-1, c: c+1) { ret.append(tile)}
        if let tile = tileAt(r: r, c: c-1) { ret.append(tile)}
        if let tile = tileAt(r: r, c: c+1) { ret.append(tile)}
        if let tile = tileAt(r: r+1, c: c) { ret.append(tile)}
        if let tile = tileAt(r: r+1, c: c-1) { ret.append(tile)}
        if let tile = tileAt(r: r+1, c: c+1) { ret.append(tile)}
        return ret
    }
    
    private func setNumbers() {
        for r in 0...rows-1 {
            for c in 0...cols-1 {
                if (tileAt(r: r, c: c)!.value != .Mine) {
                    switch numberOfAdjacentMines(r: r, c: c) {
                    case 1:
                        tiles[r][c].setValue(val: .One)
                    case 2:
                        tiles[r][c].setValue(val: .Two)
                    case 3:
                        tiles[r][c].setValue(val: .Three)
                    case 4:
                        tiles[r][c].setValue(val: .Four)
                    case 5:
                        tiles[r][c].setValue(val: .Five)
                    case 6:
                        tiles[r][c].setValue(val: .Six)
                    case 7:
                        tiles[r][c].setValue(val: .Seven)
                    case 8:
                        tiles[r][c].setValue(val: .Eight)
                    default:
                        tiles[r][c].setValue(val: .Empty)
                    }
                }
            }
        }
    }
    
    func revealAt(r: Int, c: Int) -> Bool {
        let tile = tiles[r][c]
        print("[" + String(r) + ", " + String(c) + "]")
        
        if tile.state != .Uncovered {
            NotificationCenter.default.post(name: .updateStat, object: "Effective", userInfo: ["Effective": 0])
            
            if tileAt(r: r, c: c)?.value == .Empty || (tileAt(r: r, c: c)?.value != .Mine && !getAdjacentTiles(r: r, c: c).contains(where: { $0.value == .Empty })) {
                NotificationCenter.default.post(name: .updateStat, object: "3BV", userInfo: ["3BV": 0])
            }
            
            if tile.value == .Empty {
                reveal(r: r, c: c)
            } else {
                if revealedTiles == 0 && Defaults[.safeFirstClick] && tile.value == .Mine && !loadedBoard {
                    
                    let allTiles = getAdjacentTiles(r: tile.r, c: tile.c) + [tile]
                    
                    allTiles.forEach { adjTile in
                        createBlankFrom(row: adjTile.r, col: adjTile.c, avoid: allTiles)
                    }
                    setNumbers()
                    reveal(r: r, c: c)
                } else {
                    tile.setState(state: .Uncovered)
                    revealedTiles += 1
                }
            }
        } else {
            NotificationCenter.default.post(name: .updateStat, object: 0, userInfo: ["NonEffective": 0])
        }
        
        NotificationCenter.default.post(name: .updateStat, object: "Left", userInfo: ["Left": 0])
        
        if tile.value == .Mine {
            tile.setValue(val: .MineRed)
            tile.setState(state: .Uncovered)
            revealedTiles += 1
            return true
        }
        return false
    }
    
    private func reveal(r: Int, c: Int) {
        tiles[r][c].setState(state: .Uncovered)
        revealedTiles += 1
        
        for tile in getAdjacentTiles(r: r, c: c) {
            if tile.isNumber() {
                if tiles[tile.r][tile.c].state != .Uncovered {
                    tiles[tile.r][tile.c].setState(state: .Uncovered)
                    revealedTiles += 1
                }
            }
            if tile.value == .Empty && tile.state == .Covered {
                reveal(r: tile.r, c: tile.c)
            }
        }
    }
    
    func setAt(r: Int, c: Int, state: State) {
        let tile = tiles[r][c]
        
        switch state {
        case .Covered:
            tile.setState(state: .Covered)
        case .Uncovered:
            tile.setState(state: .Uncovered)
            revealedTiles += 1
        case .Flagged:
            tile.setState(state: .Flagged)
        case .Question:
            tile.setState(state: .Question)
        }
    }
    
    func tileAt(r: Int, c: Int) -> Tile? {
        if r < 0 || r > rows-1 || c < 0 || c > cols-1 {
            return nil
        }
        return tiles[r][c]
    }
    
    func lostGame() {
        for r in 0...rows-1 {
            for c in 0...cols-1 {
                let tile = tiles[r][c]
                if tile.state == .Flagged && tile.value != .Mine {
                    tile.setValue(val: .MineWrong)
                }
                if (tile.value == .Mine && tile.state != .Flagged) || tile.value == .MineWrong {
                    tile.setState(state: .Uncovered)
                }
            }
        }
    }
    
    func reset() {
        loadedBoard = false
        initBoard()
    }
    
    func restart() {
        initBoard(restart: true)
    }
    
    func flagMines() {
        for r in 0...rows-1 {
            for c in 0...cols-1 {
                let tile = tiles[r][c]
                
                if tile.value == .Mine && tile.state != .Flagged {
                    tile.setState(state: .Flagged)
                }
            }
        }
    }
    
    private func createBlankFrom(row: Int, col: Int, avoid: [Tile]) {
        if tiles[row][col].value != .Mine {
            return
        }
        tiles[row][col].setValue(val: .Empty)
        var new = tiles[Int.random(in: 0..<rows-1)][Int.random(in: 0..<cols-1)]
        
        while new.value != .Empty || avoid.contains(new) {
            new = tiles[Int.random(in: 0..<rows-1)][Int.random(in: 0..<cols-1)]
        }
        new.setValue(val: .Mine)
        
        minesLayout.removeAll(where: { $0 == (row, col) })
        minesLayout.append((new.r, new.c))
    }
}

extension Board {
    
    func floodFill(marked: inout [[Bool]], x: Int, y: Int, m: Int, n: Int) {
        if x < 0 || x >= m || y < 0 || y >= n || marked[x][y] {
            return
        }

        marked[x][y] = true

        if tiles[x][y].value != .Empty  {
            return
        }

        let directions = [(-1, -1), (-1, 0), (-1, 1), (0, -1), (0, 1), (1, -1), (1, 0), (1, 1)]
        for (dx, dy) in directions {
            floodFill(marked: &marked, x: x + dx, y: y + dy, m: m, n: n)
        }
    }
    
    func calculate3BV() -> Int {
        let m = tiles.count
        let n = tiles[0].count
        var marked = Array(repeating: Array(repeating: false, count: n), count: m)
        var bvCount = 0

        // Count regions of empty tiles
        for x in 0..<m {
            for y in 0..<n {
                if tiles[x][y].value == .Empty && !marked[x][y] {
                    bvCount += 1
                    floodFill(marked: &marked, x: x, y: y, m: m, n: n)
                }
            }
        }

        // Count individually revealed numbered tiles
        for x in 0..<m {
            for y in 0..<n {
                if !marked[x][y] && tiles[x][y].isNumber() {
                    bvCount += 1
                }
            }
        }

        return bvCount
    }
}
