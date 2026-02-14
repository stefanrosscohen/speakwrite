import { useState } from "react";

interface SearchBarProps {
  onSearch: (handle: string) => void;
  onClear: () => void;
  activeHandle: string | null;
}

export function SearchBar({ onSearch, onClear, activeHandle }: SearchBarProps) {
  const [value, setValue] = useState("");

  const handleSubmit = () => {
    const trimmed = value.trim();
    if (trimmed) {
      onSearch(trimmed);
    }
  };

  return (
    <div
      className="flex items-center gap-2 px-4 py-2"
      style={{
        borderBottom: "1px solid var(--border)",
        background: "var(--bg-primary)",
      }}
    >
      <span
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "10px",
          color: "var(--text-secondary)",
          flexShrink: 0,
        }}
      >
        &gt;
      </span>

      {activeHandle ? (
        <div className="flex items-center gap-2 flex-1">
          <span
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "12px",
              color: "var(--accent)",
            }}
          >
            @{activeHandle}
          </span>
          <button
            onClick={() => {
              onClear();
              setValue("");
            }}
            style={{
              fontFamily: "var(--font-mono)",
              fontSize: "10px",
              color: "var(--text-secondary)",
              background: "none",
              border: "1px solid var(--border)",
              padding: "2px 8px",
              cursor: "pointer",
            }}
          >
            clear
          </button>
        </div>
      ) : (
        <input
          type="text"
          placeholder="filter by handle..."
          value={value}
          onChange={(e) => setValue(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === "Enter") handleSubmit();
          }}
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          style={{
            flex: 1,
            padding: "4px 0",
            fontFamily: "var(--font-mono)",
            fontSize: "12px",
            background: "transparent",
            color: "var(--text-primary)",
            border: "none",
            outline: "none",
            caretColor: "var(--accent)",
          }}
        />
      )}
    </div>
  );
}
