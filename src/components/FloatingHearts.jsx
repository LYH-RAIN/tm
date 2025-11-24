import React from 'react';

function FloatingHearts() {
  const hearts = Array.from({ length: 15 }, (_, i) => ({
    id: i,
    left: `${Math.random() * 100}%`,
    delay: `${Math.random() * 4}s`,
    duration: `${4 + Math.random() * 2}s`,
    size: `${20 + Math.random() * 20}px`
  }));

  return (
    <div className="fixed inset-0 pointer-events-none overflow-hidden">
      {hearts.map(heart => (
        <i
          key={heart.id}
          className="fas fa-heart heart-float text-pink-light"
          style={{
            left: heart.left,
            fontSize: heart.size,
            animationDelay: heart.delay,
            animationDuration: heart.duration,
            top: '100%'
          }}
        />
      ))}
    </div>
  );
}

export default FloatingHearts;
