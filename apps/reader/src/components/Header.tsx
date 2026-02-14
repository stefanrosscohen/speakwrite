interface HeaderProps {
  children?: React.ReactNode;
}

export function Header({ children }: HeaderProps) {
  return (
    <header
      className="flex items-center justify-between px-4 py-3 flex-shrink-0"
      style={{
        borderBottom: "1px solid var(--border)",
        background: "var(--bg-secondary)",
      }}
    >
      <span
        style={{
          fontFamily: "var(--font-mono)",
          fontSize: "11px",
          fontWeight: 600,
          letterSpacing: "0.15em",
          textTransform: "uppercase" as const,
          color: "var(--accent)",
        }}
      >
        speakwrite reader
      </span>
      {children}
    </header>
  );
}
