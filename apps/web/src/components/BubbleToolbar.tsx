import type { Editor } from "@tiptap/core";

interface BubbleToolbarProps {
  editor: Editor;
}

interface ToolbarButton {
  label: string;
  icon: string;
  action: () => void;
  isActive: () => boolean;
}

export function BubbleToolbar({ editor }: BubbleToolbarProps) {
  const buttons: ToolbarButton[] = [
    {
      label: "Bold",
      icon: "B",
      action: () => editor.chain().focus().toggleBold().run(),
      isActive: () => editor.isActive("bold"),
    },
    {
      label: "Italic",
      icon: "I",
      action: () => editor.chain().focus().toggleItalic().run(),
      isActive: () => editor.isActive("italic"),
    },
    {
      label: "Underline",
      icon: "U",
      action: () => editor.chain().focus().toggleUnderline().run(),
      isActive: () => editor.isActive("underline"),
    },
    {
      label: "Strikethrough",
      icon: "S",
      action: () => editor.chain().focus().toggleStrike().run(),
      isActive: () => editor.isActive("strike"),
    },
    {
      label: "Code",
      icon: "<>",
      action: () => editor.chain().focus().toggleCode().run(),
      isActive: () => editor.isActive("code"),
    },
    {
      label: "Highlight",
      icon: "\uD83D\uDD8D",
      action: () => editor.chain().focus().toggleHighlight().run(),
      isActive: () => editor.isActive("highlight"),
    },
    {
      label: "Link",
      icon: "\uD83D\uDD17",
      action: () => {
        if (editor.isActive("link")) {
          editor.chain().focus().unsetLink().run();
        } else {
          const url = window.prompt("URL:");
          if (url) {
            editor.chain().focus().setLink({ href: url }).run();
          }
        }
      },
      isActive: () => editor.isActive("link"),
    },
  ];

  return (
    <div className="bubble-toolbar">
      {buttons.map((btn) => (
        <button
          key={btn.label}
          className={`bubble-toolbar-btn ${btn.isActive() ? "is-active" : ""}`}
          onClick={btn.action}
          title={btn.label}
        >
          {btn.icon}
        </button>
      ))}
    </div>
  );
}
