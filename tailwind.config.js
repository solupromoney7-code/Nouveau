/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./pages/**/*.{js,jsx}",
    "./components/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      fontFamily: {
        display: ["Fraunces", "Georgia", "serif"],
        body: ["Work Sans", "system-ui", "sans-serif"],
        mono: ["IBM Plex Mono", "monospace"],
      },
      colors: {
        ink: "#1C2033",
        inkdeep: "#14172A",
        paper: "#F7F3E9",
        paperdim: "#EDE6D3",
        gold: "#C9A227",
        golddark: "#A5821A",
        wine: "#7A2E3B",
        mist: "#9498AC",
        forest: "#4F7A5C",
        inktext: "#241F17",
        inktextdim: "#4A4232",
        bglight: "#FBF9F4",
        bglightalt: "#F4F1E9",
        sage: "#6B9080",
        sagedark: "#547567",
        sky: "#5B7FA6",
        mutedlight: "#70748C",
      },
    },
  },
  plugins: [],
};
