import "./globals.css";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "AI Digital Twin",
  description: "Week 1-5 Digital Twin",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
