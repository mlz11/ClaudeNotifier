import Foundation

// MARK: - Raw Terminal Mode

func enableRawMode() -> termios {
    var original = termios()
    tcgetattr(STDIN_FILENO, &original)

    var raw = original
    // Disable canonical mode and echo
    raw.c_lflag &= ~UInt(ECHO | ICANON)
    // Read one byte at a time
    withUnsafeMutablePointer(to: &raw.c_cc) { ptr in
        let ccPtr = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: cc_t.self)
        ccPtr[Int(VMIN)] = 1
        ccPtr[Int(VTIME)] = 0
    }
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &raw)

    return original
}

func disableRawMode(_ original: termios) {
    var orig = original
    tcsetattr(STDIN_FILENO, TCSAFLUSH, &orig)
}

// MARK: - Key Input

enum KeyInput {
    case up
    case down
    case enter
    case escape
    case other
}

/// Check if stdin has data available within the given timeout (milliseconds).
private func stdinHasData(timeoutMs: Int32) -> Bool {
    var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
    return poll(&pfd, 1, timeoutMs) > 0
}

/// Parse an escape sequence after the initial 0x1B byte has been read.
private func readEscapeSequence() -> KeyInput {
    // Wait briefly to see if more bytes follow (arrow keys send ESC [ A/B)
    guard stdinHasData(timeoutMs: 50) else { return .escape }
    var seq: [UInt8] = [0, 0]
    let r1 = read(STDIN_FILENO, &seq, 1)
    if r1 != 1 { return .escape }
    guard stdinHasData(timeoutMs: 50) else { return .escape }
    let r2 = read(STDIN_FILENO, &seq[1], 1)
    if r2 != 1 { return .escape }
    if seq[0] == 0x5B { // '['
        switch seq[1] {
        case 0x41: return .up // A
        case 0x42: return .down // B
        default: return .other
        }
    }
    return .escape
}

func readKey() -> KeyInput {
    var buf: [UInt8] = [0]
    let bytesRead = read(STDIN_FILENO, &buf, 1)
    guard bytesRead == 1 else { return .other }

    switch buf[0] {
    case 0x1B:
        return readEscapeSequence()
    case 0x0A, 0x0D:
        return .enter
    default:
        return .other
    }
}

// MARK: - Menu Rendering

struct MenuItem {
    let label: String
    let value: String
    let isCurrent: Bool
}

/// Renders an interactive menu, returns the selected value or nil on Esc.
func renderMenu(title: String, items: [MenuItem], selectedIndex: Int) -> String? {
    var index = selectedIndex

    while true {
        // Clear screen and move cursor to top
        print("\u{001B}[2J\u{001B}[H", terminator: "")

        print(header(title))
        print(hint("(↑/↓ navigate, Enter select, Esc back)"))
        print("")

        for (i, item) in items.enumerated() {
            let pointer = (i == index) ? info("❯") : " "
            let label = (i == index) ? info(item.label) : item.label
            let marker = item.isCurrent ? success(" ✓") : ""
            print("  \(pointer) \(label)\(marker)")
        }

        fflush(stdout)

        let key = readKey()
        switch key {
        case .up:
            index = (index - 1 + items.count) % items.count
        case .down:
            index = (index + 1) % items.count
        case .enter:
            return items[index].value
        case .escape:
            return nil
        case .other:
            break
        }
    }
}
