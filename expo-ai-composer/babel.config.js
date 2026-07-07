// Used only by Jest (via babel-jest) to transform TypeScript/JSX test + source
// files. Not part of the published package and unrelated to the build (tsc).
module.exports = {
  presets: [require.resolve("expo/internal/babel-preset")],
};
